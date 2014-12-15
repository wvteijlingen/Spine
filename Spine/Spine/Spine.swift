//
//  Resource.swift
//  Spine
//
//  Created by Ward van Teijlingen on 21-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation
import BrightFutures

/// The domain used for errors
let SPINE_ERROR_DOMAIN = "com.wardvanteijlingen.Spine"

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
	
		var future: Future<(Int?, NSData?)>
	
		// Create or update the main resource
		if let uniqueIdentifier = resource.uniqueIdentifier {
			let URLString = self.router.URLForQuery(Query(resource: resource)).absoluteString!
			future = self.HTTPClient.put(URLString, json: self.serializer.serializeResources([resource], mode: .DirtyAttributes))
		} else {
			resource.id = NSUUID().UUIDString
			let URLString = self.router.URLForQuery(Query(resourceType: resource.type)).absoluteString!
			future = self.HTTPClient.post(URLString, json: self.serializer.serializeResources([resource], mode: .AllAttributes))
		}
		
		// Act on the future
		future.onSuccess { statusCode, data in
			// Map the response back onto the resource
			if let data = data {
				let store = Store(objects: [resource])
				let mappedResourcesStore = self.serializer.deserializeData(data, usingStore: store)
			}

			self.updateResourceRelationships(resource).onSuccess {
				// Resolve the promise
				promise.success(resource)
			}.onFailure { error in
				println("Error updating resource relationships: \(error)")
			}
			
		}.onFailure { error in
			promise.error(error)
		}
		
		// Return the outer future
		return promise.future
	}
	
	private func updateResourceRelationships(resource: Resource) -> Future<Void> {
		let promise = Promise<Void>()
		/*
		// Check if we have any new linked resources and link them
		for (attributeName, attribute) in resource.persistentAttributes {
			if !attribute.isRelationship() {
				continue
			}
			
			// TODO: Support ToOne relationships
			if attribute.type == .ToMany {
				let linkedResources = resource.valueForKey(attributeName) as ResourceCollection
				
				self.relateResources(linkedResources.addedResources, toResource: resource, relationship: attributeName).onSuccess {
					linkedResources.addedResources = []
					
					self.unrelateResources(linkedResources.removedResources, fromResource: resource, relationship: attributeName).onSuccess {
						linkedResources.removedResources = []
						promise.success()
					}.onFailure { error in
						println("Error unrelating removed resources: \(error)")
						promise.error(error)
					}
					
				}.onFailure { error in
					println("Error relating added resources: \(error)")
					promise.error(error)
				}
			}
		}
		*/
		
		// TODO: Fix this mess
		
		promise.success()
		
		return promise.future
	}

	
	// MARK: Relating
	
	/**
	Performs a request to relate the given resources to a resource for a certain relationship.
	This will fire a POST request to an URL of the form: /{resourceType}/{id}/links/{relationship}
	
	:param: resources         The resources to relate.
	:param: toResource        The resource to relate to.
	:param: relationship      The name of the relationship to relate the resources for.
	:param: completionHandler Function to call after completion.
	*/
	private func relateResources(resources: [Resource], toResource: Resource, relationship: String) -> Future<Void> {
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
	
	/**
	Performs a request to unrelate the given resources to a resource for a certain relationship.
	This will fire a DELETE request to an URL of the form: /{resourceType}/{id}/links/{relationship}/{ids}
	
	:param: resources         The resources to remove from the relation
	:param: fromResource      The resource from which to remove the related resources
	:param: relationship      The name of the relationship from which to unrelate the resources
	:param: completionHandler Function to call after completion
	*/
	private func unrelateResources(resources: [Resource], fromResource: Resource, relationship: String) -> Future<Void> {
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
	
	public func authenticate(URLString: String, username: String, password: String, scope: String? = nil) -> Future<Void> {
		return self.HTTPClient.authenticate(self.router.absoluteURLFromString(URLString).absoluteString!, username: username, password: password, scope: scope)
	}
	
	public func authenticate(URLString: String, refreshToken: String) -> Future<Void> {
		return self.HTTPClient.authenticate(self.router.absoluteURLFromString(URLString).absoluteString!, refreshToken: refreshToken)
	}
}