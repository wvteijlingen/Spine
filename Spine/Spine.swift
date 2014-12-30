//
//  Resource.swift
//  Spine
//
//  Created by Ward van Teijlingen on 21-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation
import BrightFutures

/// The domain used for errors that occur within the Spine framework.
let SPINE_ERROR_DOMAIN = "com.wardvanteijlingen.Spine"

// The domain used for errors that are returned by the API.
let SPINE_API_ERROR_DOMAIN = "com.wardvanteijlingen.Spine.Api"

/**
What this framework is all about ;)
*/
public class Spine {
	
	public class var sharedInstance: Spine {
		struct Singleton {
			static let instance = Spine()
		}
		
		return Singleton.instance
	}
	
	/// The base URL of the API. All other URLs will be made absolute to this URL.
	public var baseURL: NSURL {
		get {
			return self.router.baseURL
		}
		set {
			self.router.baseURL = newValue
		}
	}
	
	/// The router that builds the URLs for requests.
	private var router: Router
	
	/// The HTTPClient that performs the HTTP requests.
	private var HTTPClient: HTTPClientProtocol
	
	/// The serializer to use for serializing and deserializing of JSON representations.
	private var serializer: JSONAPISerializer
	
	/// Whether the print debug information
	public var traceEnabled: Bool = false {
		didSet {
			self.HTTPClient.traceEnabled = traceEnabled
		}
	}
	
	// MARK: Initializers
	
	public init(baseURL: NSURL! = nil) {
		self.HTTPClient = AlamofireClient()
		self.router = JSONAPIRouter()
		self.serializer = JSONAPISerializer()
		
		if baseURL != nil {
			self.baseURL = baseURL
		}
	}
	
	
	// MARK: Mapping
	
	/**
	Registers the given class as a resource class.
	
	:param: type The class type.
	*/
	public func registerType(type: Resource.Type) {
		self.serializer.registerClass(type)
	}
	
	
	// MARK: Fetching
	
	/**
	Fetches a resource with the given type and ID.
	
	:param: resourceType The type of resource to fetch. Must be plural.
	:param: ID           The ID of the resource to fetch.
	:param: success      Function to call after success.
	:param: failure      Function to call after failure.
	*/
	public func fetchResourceForQuery(query: Query) -> Future<Resource> {
		let promise = Promise<Resource>()
		
		self.fetchResourcesForQuery(query).onSuccess { resources in
			promise.success(resources.resources!.first!)
		}.onFailure { error in
			promise.error(error)
		}
		
		return promise.future
	}
	
	/**
	Fetches resources by executing the given query.
	
	:param: query The query to execute.
	
	:returns: Future of an array of resources.
	*/
	public func fetchResourcesForQuery(query: Query) -> Future<(ResourceCollection)> {
		let promise = Promise<ResourceCollection>()
		
		let URLString = self.router.URLForQuery(query).absoluteString!
		
		self.HTTPClient.get(URLString).onSuccess { statusCode, data in
			
			if 200 ... 299 ~= statusCode! {
				let deserializationResult = self.serializer.deserializeData(data!)
				
				if let store = deserializationResult.store {
					let collection = ResourceCollection(store.allObjectsWithType(query.resourceType))
					collection.paginationData = deserializationResult.pagination
					
					promise.success(collection)
					
				} else {
					promise.error(deserializationResult.error!)
				}
				
			} else {
				let error = self.serializer.deserializeError(data!, withResonseStatus: statusCode!)
				promise.error(error)
			}
			
			}.onFailure { error in
				promise.error(error)
		}
		
		return promise.future
	}
	
	
	// MARK: Saving
	
	/**
	Saves a resource to the server.
	This will also relate and unrelate any pending related and unrelated resource.
	Related resources will not be saved automatically. You must ensure that related resources are saved before saving any parent resource.
	
	:param: resource The resource to save.
	
	:returns: Future of the resource saved.
	*/
	public func saveResource(resource: Resource) -> Future<Resource> {
		let promise = Promise<Resource>()
		
		var saveFuture: Future<(Int?, NSData?)>
		var shouldUpdateRelationships = false
		
		// Create or update the main resource
		if let uniqueIdentifier = resource.uniqueIdentifier {
			shouldUpdateRelationships = true
			let URLString = self.router.URLForQuery(Query(resource: resource)).absoluteString!
			let json = self.serializer.serializeResources([resource])
			saveFuture = self.HTTPClient.put(URLString, json: json)
		} else {
			resource.id = NSUUID().UUIDString
			let URLString = self.router.URLForQuery(Query(resourceType: resource.type)).absoluteString!
			let json = self.serializer.serializeResources([resource], options: SerializationOptions(dirtyAttributesOnly: false, includeToOne: true, includeToMany: true))
			saveFuture = self.HTTPClient.post(URLString, json: json)
		}
		
		// Act on the future
		saveFuture.onSuccess { statusCode, data in
			// Map the response back onto the resource
			if let data = data {
				self.serializer.deserializeData(data, usingStore: Store(objects: [resource]), options: DeserializationOptions(mapOntoFirstResourceInStore: true))
			}
			
			// Separately update relationships if needed
			if shouldUpdateRelationships == false {
				promise.success(resource)
			} else {
				self.updateResourceRelationships(resource).onSuccess {
					promise.success(resource)
					}.onFailure { error in
						println("Error updating resource relationships: \(error)")
						promise.error(error)
				}
			}
			
			}.onFailure { error in
				promise.error(error)
		}
		
		// Return the public future
		return promise.future
	}
	
	private func updateResourceRelationships(resource: Resource) -> Future<Void> {
		let promise = Promise<Void>()
		
		typealias Operation = (relationship: String, type: String, resources: [Resource])
		
		var operations: [Operation] = []
		
		// Create operations
		for attribute in resource.persistentAttributes {
			switch attribute.type {
			case let toOne as ToOneType:
				let linkedResource = resource.valueForKey(attribute.name) as LinkedResource
				if linkedResource.hasChanged && linkedResource.resource != nil {
					operations.append((relationship: attribute.name, type: "replace", resources: [linkedResource.resource!]))
				}
			case let toMany as ToManyType:
				let linkedResources = resource.valueForKey(attribute.name) as ResourceCollection
				operations.append((relationship: attribute.name, type: "add", resources: linkedResources.addedResources))
				operations.append((relationship: attribute.name, type: "remove", resources: linkedResources.removedResources))
			default: ()
			}
		}
		
		// Run the operations
		var stop = false
		for operation in operations {
			if stop {
				break
			}
			
			switch operation.type {
			case "add":
				self.addRelatedResources(operation.resources, toResource: resource, relationship: operation.relationship).onFailure { error in
					promise.error(error)
					stop = true
				}
			case "remove":
				self.removeRelatedResources(operation.resources, fromResource: resource, relationship: operation.relationship).onFailure { error in
					promise.error(error)
					stop = true
				}
			case "replace":
				self.updateRelatedResource(operation.resources.first!, ofResource: resource, relationship: operation.relationship).onFailure { error in
					promise.error(error)
					stop = true
				}
			default: ()
			}
		}
		
		return promise.future
	}
	
	
	// MARK: Relating
	
	private func addRelatedResources(resources: [Resource], toResource: Resource, relationship: String) -> Future<Void> {
		let promise = Promise<Void>()
		
		if resources.count > 0 {
			let ids: [String] = resources.map { resource in
				assert(resource.uniqueIdentifier != nil, "Attempt to relate resource without unique identifier. Only existing resources can be related.")
				return resource.uniqueIdentifier!.id
			}
			
			let URLString = self.router.URLForRelationship(relationship, ofResource: toResource).absoluteString!
			
			self.HTTPClient.post(URLString, json: [relationship: ids]).onSuccess { statusCode, data in
				promise.success()
				}.onFailure { error in
					promise.error(error)
			}
		} else {
			promise.success()
		}
		
		return promise.future
	}
	
	private func removeRelatedResources(resources: [Resource], fromResource: Resource, relationship: String) -> Future<Void> {
		let promise = Promise<Void>()
		
		if resources.count > 0 {
			let ids: [String] = resources.map { (resource) in
				assert(resource.uniqueIdentifier != nil, "Attempt to unrelate resource without unique identifier. Only existing resources can be unrelated.")
				return resource.uniqueIdentifier!.id
			}
			
			let URLString = self.router.URLForRelationship(relationship, ofResource: fromResource, ids: ids).absoluteString!
			
			self.HTTPClient.delete(URLString).onSuccess { statusCode, data in
				promise.success()
				}.onFailure { error in
					promise.error(error)
			}
		} else {
			promise.success()
		}
		
		return promise.future
	}
	
	private func updateRelatedResource(resource: Resource, ofResource: Resource, relationship: String) -> Future<Void> {
		let promise = Promise<Void>()
		
		let URLString = self.router.URLForRelationship(relationship, ofResource: ofResource).absoluteString!
		
		self.HTTPClient.put(URLString, json: [relationship: resource.id!]).onSuccess { statusCode, data in
			promise.success()
			}.onFailure { error in
				promise.error(error)
		}
		
		return promise.future
	}
	
	
	// MARK: Deleting
	
	/**
	Deletes the resource from the server.
	This will fire a DELETE request to an URL of the form: /{resourceType}/{id}.
	
	:param: resource The resource to delete.
	
	:returns: Void future.
	*/
	public func deleteResource(resource: Resource) -> Future<Void> {
		let promise = Promise<Void>()
		
		let URLString = self.router.URLForQuery(Query(resource: resource)).absoluteString!
		
		self.HTTPClient.delete(URLString).onSuccess { statusCode, data in
			promise.success()
			}.onFailure { error in
				promise.error(error)
		}
		
		return promise.future
	}
	
	
	// MARK: OAuth
	
	public func authenticate(URLString: String, username: String, password: String, scope: String? = nil) -> Future<OAuthCredential> {
		return self.HTTPClient.authenticate(self.router.absoluteURLFromString(URLString).absoluteString!, username: username, password: password, scope: scope)
	}
	
	public func authenticate(URLString: String, credential: OAuthCredential) -> Future<OAuthCredential> {
		return self.HTTPClient.authenticate(self.router.absoluteURLFromString(URLString).absoluteString!, credential: credential)
	}
	
	public func authenticate(URLString: String, refreshToken: String) -> Future<OAuthCredential> {
		return self.HTTPClient.authenticate(self.router.absoluteURLFromString(URLString).absoluteString!, refreshToken: refreshToken)
	}
	
	public func revokeAuthentication() {
		self.HTTPClient.revokeAuthentication()
	}
}