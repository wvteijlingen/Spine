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
	var router: Router = JSONAPIRouter()
	
	/// The HTTPClient that performs the HTTP requests.
	var HTTPClient: _HTTPClientProtocol = URLSessionClient()
	
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

	func fetchResourcesByExecutingQuery<T: ResourceProtocol>(query: Query<T>, mapOnto mappingTargets: [ResourceProtocol] = []) -> Future<(ResourceCollection)> {
		let promise = Promise<ResourceCollection>()
		
		let URL = self.router.URLForQuery(query)
		
		HTTPClient.request(.GET, URL: URL) { statusCode, responseData, error in
			if let error = error {
				promise.error(self.handleErrorResponse(statusCode, responseData: responseData, error: error))
				
			} else {
				let deserializationResult = self.serializer.deserializeData(responseData!, mappingTargets: mappingTargets)
				
				switch deserializationResult {
				case .Success(let resources, let paginationData):
					let collection = ResourceCollection(resources: resources)
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

		var isNewResource = (resource.id == nil)
		var request: HTTPClientRequestMethod
		var URL: NSURL
		var payload: NSData
		
		if isNewResource {
			request = .POST
			URL = router.URLForResourceType(resource.type)
			payload = serializer.serializeResources([resource], options: SerializationOptions(includeID: false, dirtyAttributesOnly: false, includeToOne: true, includeToMany: true))
		} else {
			request = .PUT
			URL = router.URLForQuery(Query(resource: resource))
			payload = serializer.serializeResources([resource])
		}
		
		HTTPClient.request(request, URL: URL, payload: payload) { statusCode, responseData, error in
			if let error = error {
				promise.error(self.handleErrorResponse(statusCode, responseData: responseData, error: error))
				return
			}
			
			// Map the response back onto the resource
			if let data = responseData {
				self.serializer.deserializeData(data, mappingTargets: [resource])
			}
			
			// Separately update relationships if this is an existing resource
			if isNewResource {
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
		
		// Return the public future
		return promise.future
	}
	
	
	// MARK: Relating
	
	// TODO: Use the JSON:API PATCH extension so we can coalesce updates into one request
	private func updateRelationshipsOfResource(resource: ResourceProtocol) -> Future<Void> {
		let promise = Promise<Void>()
		
		typealias Operation = (relationship: String, type: String, resources: [ResourceProtocol])
		
		var operations: [Operation] = []
		
		// Create operations
		for field in resource.fields {
			switch field {
			case let toOne as ToOneRelationship:
				let linkedResource = resource.valueForField(field.name) as ResourceProtocol
				if linkedResource.id != nil {
					operations.append((relationship: field.serializedName, type: "replace", resources: [linkedResource]))
				}
			case let toMany as ToManyRelationship:
				let linkedResources = resource.valueForField(field.name) as LinkedResourceCollection
				operations.append((relationship: field.serializedName, type: "add", resources: linkedResources.addedResources))
				operations.append((relationship: field.serializedName, type: "remove", resources: linkedResources.removedResources))
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
			
			let URL = self.router.URLForRelationship(relationship, ofResource: toResource)
			let payload = NSJSONSerialization.dataWithJSONObject([relationship: ids], options: NSJSONWritingOptions(0), error: nil)
			// TODO: Move serialization
			self.HTTPClient.request(.POST, URL: URL, payload: payload) { statusCode, responseData, error in
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
			
			let URL = router.URLForRelationship(relationship, ofResource: fromResource, ids: ids)
			
			self.HTTPClient.request(.DELETE, URL: URL) { statusCode, responseData, error in
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
		
		let URL = router.URLForRelationship(relationship, ofResource: ofResource)
		let payload = NSJSONSerialization.dataWithJSONObject([relationship: resource.id!], options: NSJSONWritingOptions(0), error: nil)
		// TODO: Move serialization
		
		self.HTTPClient.request(.PUT, URL: URL, payload: payload) { statusCode, responseData, error in
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
		
		let URL = self.router.URLForQuery(Query(resource: resource))
		
		self.HTTPClient.request(.DELETE, URL: URL) { statusCode, responseData, error in
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
	/**
	Fetch multiple resources with the given IDs and type.
	
	:test: SpineTests.testFindByIDAndType
	
	:param: IDs  IDs of resources to fetch.
	:param: type The type of resource to fetch.
	
	:returns: A future that resolves to a ResourceCollection that contains the fetched resources.
	*/
	func find<T: ResourceProtocol>(IDs: [String], ofType type: T.Type) -> Future<ResourceCollection> {
		let query = Query(resourceType: type, resourceIDs: IDs)
		return fetchResourcesByExecutingQuery(query)
	}

	/**
	Fetch all resources with the given type.
	This does not explicitly impose any limit, but the server may choose to limit the response.
	
	:test: SpineTests.testFindByType
	
	:param: type The type of resource to fetch.
	
	:returns: A future that resolves to a ResourceCollection that contains the fetched resources.
	*/
	func find<T: ResourceProtocol>(type: T.Type) -> Future<ResourceCollection> {
		let query = Query(resourceType: type)
		return fetchResourcesByExecutingQuery(query)
	}
	
	/**
	Fetch one resource with the given ID and type.
	
	:test: SpineTests.testFindOneByIDAndType
	
	:param: ID   ID of resource to fetch.
	:param: type The type of resource to fetch.
	
	:returns: A future that resolves to the fetched resource.
	*/
	func findOne<T: ResourceProtocol>(ID: String, ofType type: T.Type) -> Future<T> {
		let query = Query(resourceType: type, resourceIDs: [ID])
		return findOne(query)
	}
	
	/**
	Fetch multiple resources using the given query..
	
	// :test: SpineTests.testFindByQuery
	
	:param: query The query describing which resources to fetch.
	
	:returns: A future that resolves to a ResourceCollection that contains the fetched resources.
	*/
	func find<T: ResourceProtocol>(query: Query<T>) -> Future<ResourceCollection> {
		return fetchResourcesByExecutingQuery(query)
	}

	/**
	Fetch one resource using the given query..
	
	:test: SpineTests.testFindOneByQuery
	
	:param: query The query describing which resource to fetch.
	
	:returns: A future that resolves to the fetched resource.
	*/
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


// MARK: - Utilities

// Find resources with a specific type in a collection
func findResourcesWithType<C: CollectionType where C.Generator.Element: ResourceProtocol>(domain: C, type: String) -> [C.Generator.Element] {
	return filter(domain) { $0.type == type }
}

// Find a specific resource in a collection
func findResource<C: CollectionType where C.Generator.Element: ResourceProtocol>(domain: C, type: String, id: String) -> C.Generator.Element? {
	return filter(domain) { $0.type == type && $0.id == id }.first
}

// Enumerate over specific fields
func enumerateFields<T: Field>(resource: ResourceProtocol, type: T.Type, callback: (T) -> ()) {
	for field in resource.fields {
		if let attribute = field as? T {
			callback(attribute)
		}
	}
}

// Compare linkage tuples
func == (left: (String, String), right: (String, String)) -> Bool {
	return (left.0 == right.0) && (left.1 == right.1)
}

// Compare resources based on type and id
public func == <T: ResourceProtocol> (left: T, right: T) -> Bool {
	return (left.id == right.id) && (left.type == right.type)
}

// Compare array of resources based on type and id
public func == <T: ResourceProtocol> (left: [T], right: [T]) -> Bool {
	if left.count != right.count {
		return false
	}
	
	for (index, resource) in enumerate(left) {
		if (resource.type != right[index].type) || (resource.id != right[index].id) {
			return false
		}
	}
	
	return true
}

public func unloadResource(resource: ResourceProtocol) {
	for field in resource.fields {
		resource.setValue(nil, forField: field.name)
	}
	
	resource.isLoaded = false
}