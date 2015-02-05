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
public let SPINE_ERROR_DOMAIN = "com.wardvanteijlingen.Spine"

/// The domain used for errors that are returned by the API.
public let SPINE_API_ERROR_DOMAIN = "com.wardvanteijlingen.Spine.Api"

/// The main class
public class Spine {
	
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
	private var router: Router = JSONAPIRouter()
	
	/// The HTTPClient that performs the HTTP requests.
	private var HTTPClient: _HTTPClientProtocol = AlamofireClient()
	
	/// The public facing HTTPClient
	public var client: HTTPClientProtocol {
		return HTTPClient
	}
	
	/// The serializer to use for serializing and deserializing of JSON representations.
	private var serializer: JSONSerializer = JSONSerializer()
	
	/// Whether the print debug information. Default false.
	public var traceEnabled: Bool = false {
		didSet {
			self.HTTPClient.traceEnabled = traceEnabled
		}
	}
	
	/// Whether to use client side generated IDs instead of server side generated IDs. Default false.
	var useClientSideIDs: Bool = false
	
	
	// MARK: Initializers
	
	public init(baseURL: NSURL? = nil) {
		if let baseURL = baseURL {
			self.baseURL = baseURL
		}
	}
	
	
	// MARK: Error handling
	
	func handleErrorResponse(statusCode: Int?, responseData: NSData?, error: NSError) -> NSError {
		switch error.domain {
		case SPINE_ERROR_DOMAIN:
			return error
		case SPINE_API_ERROR_DOMAIN:
			return self.serializer.deserializeError(responseData!, withResonseStatus: statusCode!)
		default:
			return error
		}
	}
	

	// MARK: Fetching methods

	func fetchResourcesByExecutingQuery<T: ResourceProtocol>(query: Query<T>, mapOnto mappingTargetResources: [ResourceProtocol] = []) -> Future<(ResourceCollection)> {
		// We can only map onto resources that are not loaded yet
		for resource in mappingTargetResources {
			assert(resource.isLoaded == false, "Cannot map onto loaded resource \(resource)")
		}
		
		let promise = Promise<ResourceCollection>()
		
		let URLString = self.router.URLForQuery(query).absoluteString!
		
		self.HTTPClient.get(URLString) { statusCode, responseData, error in
			if let error = error {
				promise.error(self.handleErrorResponse(statusCode, responseData: responseData, error: error))
				
			} else {
				let deserializationResult = self.serializer.deserializeData(responseData!, usingStore: Store(objects: mappingTargetResources))
				
				switch deserializationResult {
				case .Success(let store, let paginationData):
					let collection = ResourceCollection(store.allObjectsWithType(query.resourceType), type: query.resourceType)
					collection.paginationData = paginationData
					promise.success(collection)
				case .Failure(let error):
					promise.error(error)
				}
			}
		}
		
		return promise.future
	}
	
	func loadResourceByExecutingQuery<T: ResourceProtocol>(resource: T, query: Query<T>) -> Future<T> {
		let promise = Promise<(T)>()
		
		if resource.isLoaded {
			promise.success(resource)
		} else {
			fetchResourcesByExecutingQuery(query, mapOnto: [resource]).onSuccess { resources in
				promise.success(resource)
			}.onFailure { error in
				promise.error(error)
			}
		}
		
		return promise.future
	}
	
	
	// MARK: Saving

	func saveResource(resource: ResourceProtocol) -> Future<ResourceProtocol> {
		let promise = Promise<ResourceProtocol>()

		var shouldUpdateRelationships = false
		
		var callback: HTTPClientCallback = { statusCode, responseData, error in
			if let error = error {
				promise.error(self.handleErrorResponse(statusCode, responseData: responseData, error: error))
				return
			}
			
			let deserializationOptions = (self.useClientSideIDs) ? DeserializationOptions() : DeserializationOptions(mapOntoFirstResourceInStore: true)
			
			// Map the response back onto the resource
			if let data = responseData {
				self.serializer.deserializeData(data, usingStore: [resource], options: deserializationOptions)
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
		}
		
		// Create or update the main resource
		if let id = resource.id {
			shouldUpdateRelationships = true
			let URLString = self.router.URLForQuery(Query(resource: resource)).absoluteString!
			let json = self.serializer.serializeResources([resource])
			self.HTTPClient.put(URLString, json: json, callback: callback)
		} else {
			resource.id = NSUUID().UUIDString
			let URLString = self.router.URLForResourceType(resource.type).absoluteString!
			let json = self.serializer.serializeResources([resource], options: SerializationOptions(includeID: false, dirtyAttributesOnly: false, includeToOne: true, includeToMany: true))
			self.HTTPClient.post(URLString, json: json, callback: callback)
		}
		
		// Return the public future
		return promise.future
	}
	
	
	// MARK: Relating
	
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
					operations.append((relationship: attribute.serializedName, type: "replace", resources: [linkedResource]))
				}
			case let toMany as ToManyAttribute:
				let linkedResources = resource[attribute.name] as ResourceCollection
				operations.append((relationship: attribute.serializedName, type: "add", resources: linkedResources.addedResources))
				operations.append((relationship: attribute.serializedName, type: "remove", resources: linkedResources.removedResources))
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
				self.setRelatedResource(operation.resources.first!, ofResource: resource, relationship: operation.relationship).onFailure { error in
					promise.error(error)
					stop = true
				}
			default: ()
			}
		}
		
		return promise.future
	}
	
	private func addRelatedResources(resources: [ResourceProtocol], toResource: ResourceProtocol, relationship: String) -> Future<Void> {
		let promise = Promise<Void>()
		
		if resources.count == 0 {
			promise.success()
		} else {
			let ids: [String] = resources.map { resource in
				assert(resource.id != nil, "Attempt to relate resource without id. Only existing resources can be related.")
				return resource.id!
			}
			
			let URLString = self.router.URLForRelationship(relationship, ofResource: toResource).absoluteString!
			
			self.HTTPClient.post(URLString, json: [relationship: ids]) { statusCode, responseData, error in
				if let error = error {
					promise.error(self.handleErrorResponse(statusCode, responseData: responseData, error: error))
				} else {
					promise.success()
				}
			}
		}
		
		return promise.future
	}
	
	private func removeRelatedResources(resources: [ResourceProtocol], fromResource: ResourceProtocol, relationship: String) -> Future<Void> {
		let promise = Promise<Void>()
		
		if resources.count == 0 {
			promise.success()
		} else {
			let ids: [String] = resources.map { (resource) in
				assert(resource.id != nil, "Attempt to unrelate resource without id. Only existing resources can be unrelated.")
				return resource.id!
			}
			
			let URLString = self.router.URLForRelationship(relationship, ofResource: fromResource, ids: ids).absoluteString!
			
			self.HTTPClient.delete(URLString) { statusCode, responseData, error in
				if let error = error {
					promise.error(self.handleErrorResponse(statusCode, responseData: responseData, error: error))
				} else {
					promise.success()
				}
			}
		}
		
		return promise.future
	}
	
	private func setRelatedResource(resource: ResourceProtocol, ofResource: ResourceProtocol, relationship: String) -> Future<Void> {
		let promise = Promise<Void>()
		
		let URLString = self.router.URLForRelationship(relationship, ofResource: ofResource).absoluteString!
		
		self.HTTPClient.put(URLString, json: [relationship: resource.id!]) { statusCode, responseData, error in
			if let error = error {
				promise.error(self.handleErrorResponse(statusCode, responseData: responseData, error: error))
			} else {
				promise.success()
			}
		}
		
		return promise.future
	}
	
	
	// MARK: Deleting
	
	func deleteResource(resource: ResourceProtocol) -> Future<Void> {
		let promise = Promise<Void>()
		
		let URLString = self.router.URLForQuery(Query(resource: resource)).absoluteString!
		
		self.HTTPClient.delete(URLString) { statusCode, responseData, error in
			if let error = error {
				promise.error(self.handleErrorResponse(statusCode, responseData: responseData, error: error))
			} else {
				promise.success()
			}
		}
		
		return promise.future
	}
}

// MARK: - Public functions


/**
 *  Registering resource types
 */
public extension Spine {
	/**
	Registers the given class as a resource class.
	
	:param: type The class type.
	*/
	func registerResource(type: String, factory: () -> ResourceProtocol) {
		self.serializer.resourceFactory.registerResource(type, factory: factory)
	}
}


/**
 *  Registering transformers
 */
public extension Spine {
	/**
	Registers the given class as a resource class.
	
	:param: type The class type.
	*/
	func registerTransformer<T: Transformer>(transformer: T) {
		self.serializer.transformers.registerTransformer(transformer)
	}
}

/**
 *  Finding resources
 */
public extension Spine {

	// Find one
	func findOne<T: ResourceProtocol>(ID: String, ofType type: T.Type) -> Future<T> {
		let query = Query(resourceType: type, resourceIDs: [ID])
		return findOne(query)
	}

	// Find multiple
	func find<T: ResourceProtocol>(IDs: [String], ofType type: T.Type) -> Future<ResourceCollection> {
		let query = Query(resourceType: type, resourceIDs: IDs)
		return fetchResourcesByExecutingQuery(query)
	}

	// Find all
	func find<T: ResourceProtocol>(type: T.Type) -> Future<ResourceCollection> {
		let query = Query(resourceType: type)
		return fetchResourcesByExecutingQuery(query)
	}

	// Find by query
	func find<T: ResourceProtocol>(query: Query<T>) -> Future<ResourceCollection> {
		return fetchResourcesByExecutingQuery(query)
	}

	// Find one by query
	func findOne<T: ResourceProtocol>(query: Query<T>) -> Future<T> {
		let promise = Promise<T>()
		
		fetchResourcesByExecutingQuery(query).onSuccess { resourceCollection in
			if let resource = resourceCollection.resources.first as? T {
				promise.success(resource)
			} else {
				promise.error(NSError(domain: SPINE_ERROR_DOMAIN, code: 404, userInfo: nil))
			}
		}.onFailure { error in
			promise.error(error)
		}
		
		return promise.future
	}
}

/**
 *  Persisting resources
 */
public extension Spine {
	func save(resource: ResourceProtocol) -> Future<ResourceProtocol> {
		return saveResource(resource)
	}
	
	func delete(resource: ResourceProtocol) -> Future<Void> {
		return delete(resource)
	}
}

/**
 *  Ensuring resources
 */
public extension Spine {
	
	func ensure<T: ResourceProtocol>(resource: T) -> Future<T> {
		let query = Query(resource: resource)
		return loadResourceByExecutingQuery(resource, query: query)
	}

	func ensure<T: ResourceProtocol>(resource: T, queryCallback: (Query<T>) -> Query<T>) -> Future<T> {
		let query = queryCallback(Query(resource: resource))
		return loadResourceByExecutingQuery(resource, query: query)
	}
}