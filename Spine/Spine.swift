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

/// The domain used for errors that are returned by the API.
let SPINE_API_ERROR_DOMAIN = "com.wardvanteijlingen.Spine.Api"

/// The main class
public class Spine {
	
	public class var sharedInstance: Spine {
		
		struct Singleton {
			static var instance: Spine!
			static var token: dispatch_once_t = 0
		}
		
		dispatch_once(&Singleton.token) {
			Singleton.instance = Spine()
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
	
	/// The public facing HTTPClient
	public var client: HTTPClientHeadersProtocol {
		return HTTPClient
	}
	
	/// The serializer to use for serializing and deserializing of JSON representations. Default false.
	private var serializer: JSONSerializer
	
	/// Whether the print debug information
	public var traceEnabled: Bool = false {
		didSet {
			self.HTTPClient.traceEnabled = traceEnabled
		}
	}
	
	/// Whether to use client side generated IDs instead of server side generated IDs. Default false.
	var useClientSideIDs: Bool = false
	
	
	// MARK: Initializers
	
	public init(baseURL: NSURL! = nil) {
		self.HTTPClient = AlamofireClient()
		self.router = JSONAPIRouter()
		self.serializer = JSONSerializer()
		
		if baseURL != nil {
			self.baseURL = baseURL
		}
	}
	
	
	// MARK: Public fetching methods
	
	public func fetchResourceForQuery<T: ResourceProtocol>(query: Query<T>) -> Future<T> {
		let promise = Promise<T>()
		
		self.fetch(query).onSuccess { resources in
			let resource = resources.resources!.first! as T
			promise.success(resource)
		}.onFailure { error in
			promise.error(error)
		}
		
		return promise.future
	}
	
	public func fetchResourcesForQuery<T: ResourceProtocol>(query: Query<T>) -> Future<ResourceCollection> {
		return self.fetch(query)
	}
	
	
	// MARK: Internal fetching methods

	func fetch<T: ResourceProtocol>(query: Query<T>, mapOnto mappingTargetResources: [ResourceProtocol] = []) -> Future<(ResourceCollection)> {
		// We can only map onto resources that are not loaded yet
		for resource in mappingTargetResources {
			assert(resource.isLoaded == false, "Cannot map onto loaded resource \(resource)")
		}
		
		let promise = Promise<ResourceCollection>()
		
		let URLString = self.router.URLForQuery(query).absoluteString!
		
		self.HTTPClient.get(URLString).onSuccess { statusCode, data in
			
			if 200 ... 299 ~= statusCode! {
				let store = Store(objects: mappingTargetResources)
				let deserializationResult = self.serializer.deserializeData(data!, usingStore: store)
				
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
	public func save(resource: ResourceProtocol) -> Future<ResourceProtocol> {
		let promise = Promise<ResourceProtocol>()
		
		var saveFuture: Future<(Int?, NSData?)>
		var shouldUpdateRelationships = false
		
		// Create or update the main resource
		if let id = resource.id {
			shouldUpdateRelationships = true
			let URLString = self.router.URLForQuery(Query(resource: resource)).absoluteString!
			let json = self.serializer.serializeResources([resource])
			saveFuture = self.HTTPClient.put(URLString, json: json)
		} else {
			resource.id = NSUUID().UUIDString
			let URLString = self.router.URLForResourceType(resource.type).absoluteString!
			let json = self.serializer.serializeResources([resource], options: SerializationOptions(includeID: false, dirtyAttributesOnly: false, includeToOne: true, includeToMany: true))
			saveFuture = self.HTTPClient.post(URLString, json: json)
		}
		
		// Act on the future
		saveFuture.onSuccess { statusCode, data in
			let deserializationOptions = (self.useClientSideIDs) ? DeserializationOptions() : DeserializationOptions(mapOntoFirstResourceInStore: true)
			
			// Map the response back onto the resource
			if let data = data {
				self.serializer.deserializeData(data, usingStore: Store(objects: [resource]), options: deserializationOptions)
			}
			
			// Separately update relationships if needed
			if shouldUpdateRelationships == false {
				promise.success(resource)
			} else {
				self.updateRelationshipsOfResource(resource).onSuccess {
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
	
	private func updateRelationshipsOfResource(resource: ResourceProtocol) -> Future<Void> {
		let promise = Promise<Void>()
		
		typealias Operation = (relationship: String, type: String, resources: [ResourceProtocol])
		
		var operations: [Operation] = []
		
		// Create operations
		for attribute in resource.attributes {
			switch attribute {
			case let toOne as ToOneAttribute:
				let linkedResource = resource[attribute.name] as ResourceProtocol
				if linkedResource.id != nil {
					operations.append((relationship: attribute.name, type: "replace", resources: [linkedResource]))
				}
			case let toMany as ToManyAttribute:
				let linkedResources = resource[attribute.name] as ResourceCollection
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
	
	private func addRelatedResources(resources: [ResourceProtocol], toResource: ResourceProtocol, relationship: String) -> Future<Void> {
		let promise = Promise<Void>()
		
		if resources.count > 0 {
			let ids: [String] = resources.map { resource in
				assert(resource.id != nil, "Attempt to relate resource without id. Only existing resources can be related.")
				return resource.id!
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
	
	private func removeRelatedResources(resources: [ResourceProtocol], fromResource: ResourceProtocol, relationship: String) -> Future<Void> {
		let promise = Promise<Void>()
		
		if resources.count > 0 {
			let ids: [String] = resources.map { (resource) in
				assert(resource.id != nil, "Attempt to unrelate resource without id. Only existing resources can be unrelated.")
				return resource.id!
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
	
	private func updateRelatedResource(resource: ResourceProtocol, ofResource: ResourceProtocol, relationship: String) -> Future<Void> {
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
	public func delete(resource: ResourceProtocol) -> Future<Void> {
		let promise = Promise<Void>()
		
		let URLString = self.router.URLForQuery(Query(resource: resource)).absoluteString!
		
		self.HTTPClient.delete(URLString).onSuccess { statusCode, data in
			promise.success()
			}.onFailure { error in
				promise.error(error)
		}
		
		return promise.future
	}
}

// MARK: - Resource registering

extension Spine {
	/**
	Registers the given class as a resource class.
	
	:param: type The class type.
	*/
	public func registerResource(type: String, factory: () -> ResourceProtocol) {
		self.serializer.resourceFactory.registerResource(type, factory: factory)
	}
}

// MARK: - Transformer registering

extension Spine {
	/**
	Registers the given class as a resource class.
	
	:param: type The class type.
	*/
	public func registerTransformer<T: Transformer>(transformer: T) {
		self.serializer.transformers.registerTransformer(transformer)
	}
}


// MARK: - Finders
extension Spine {

	// Find one
	public func findOne<T: ResourceProtocol>(ID: String, ofType type: T.Type) -> Future<T> {
		let query = Query(resourceType: type, resourceIDs: [ID])
		return fetchResourceForQuery(query)
	}

	// Find multiple
	public func find<T: ResourceProtocol>(IDs: [String], ofType type: T.Type) -> Future<ResourceCollection> {
		let query = Query(resourceType: type, resourceIDs: IDs)
		return fetchResourcesForQuery(query)
	}

	// Find all
	public func find<T: ResourceProtocol>(type: T.Type) -> Future<ResourceCollection> {
		let query = Query(resourceType: type)
		return fetchResourcesForQuery(query)
	}

	// Find by query
	public func find<T: ResourceProtocol>(query: Query<T>) -> Future<ResourceCollection> {
		return fetchResourcesForQuery(query)
	}

	// Find one by query
	public func findOne<T: ResourceProtocol>(query: Query<T>) -> Future<T> {
		return fetchResourceForQuery(query)
	}
}

// MARK: - Ensuring
extension Spine {
	
	public func ensure<T: ResourceProtocol>(resource: T) -> Future<T> {
		let query = Query(resource: resource)
		return ensure(resource, query: query)
	}

	public func ensure<T: ResourceProtocol>(resource: T, queryCallback: (Query<T>) -> Query<T>) -> Future<T> {
		let query = queryCallback(Query(resource: resource))
		return ensure(resource, query: query)
	}

	func ensure<T: ResourceProtocol>(resource: T, query: Query<T>) -> Future<T> {
		let promise = Promise<(T)>()
		
		if resource.isLoaded {
			promise.success(resource)
		} else {
			fetch(query, mapOnto: [resource]).onSuccess { resources in
				promise.success(resource)
			}.onFailure { error in
				promise.error(error)
			}
		}
		
		return promise.future
	}
}