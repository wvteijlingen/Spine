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
public let SpineClientErrorDomain = "com.wardvanteijlingen.spine.client"

/// The domain used for errors that are returned by the API.
public let SpineServerErrorDomain = "com.wardvanteijlingen.spine.server"

/// The main class
public class Spine {
	
	/// The router that builds the URLs for requests.
	let router: RouterProtocol
	
	/// The HTTPClient that performs the HTTP requests.
	var _HTTPClient: _HTTPClientProtocol = URLSessionClient()
	
	/// The HTTPClient used for all network requests.
	public var HTTPClient: HTTPClientProtocol {
		return _HTTPClient
	}
	
	/// The serializer to use for serializing and deserializing of JSON representations.
	private let serializer: JSONSerializer = JSONSerializer()
	
	// MARK: Initializers
	
	public init(baseURL: NSURL) {
		self.router = Router(baseURL: baseURL)
	}
	
	public init(baseURL: NSURL, router: RouterProtocol) {
		self.router = router
		self.router.baseURL = baseURL
	}
	
	// MARK: Error handling
	
	func handleErrorResponse(statusCode: Int?, responseData: NSData?, error: NSError) -> NSError {
		switch error.domain {
		case SpineServerErrorDomain:
			return serializer.deserializeError(responseData!, withResonseStatus: statusCode!)
		default:
			return error
		}
	}
	

	// MARK: Fetching methods

	func fetchResourcesByExecutingQuery<T: ResourceProtocol>(query: Query<T>, mapOnto mappingTargets: [ResourceProtocol] = []) -> Future<(ResourceCollection)> {
		let promise = Promise<ResourceCollection>()
		let URL = router.URLForQuery(query)
		
		Spine.logInfo(.Spine, "Fetching resources using URL: \(URL)")
		
		_HTTPClient.request("GET", URL: URL) { statusCode, responseData, error in
			if let error = error {
				promise.failure(self.handleErrorResponse(statusCode, responseData: responseData, error: error))
				
			} else {
				let deserializationResult = self.serializer.deserializeData(responseData!, mappingTargets: mappingTargets)
				
				switch deserializationResult {
				case .Success(let resources, let paginationData):
					let collection = ResourceCollection(resources: resources)
					collection.paginationData = paginationData
					promise.success(collection)
				case .Failure(let error):
					promise.failure(error)
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
				promise.failure(error)
			}
		}
		
		return promise.future
	}
	
	
	// MARK: Saving

	func saveResource(resource: ResourceProtocol) -> Future<ResourceProtocol> {
		let promise = Promise<ResourceProtocol>()
		
		var isNewResource = (resource.id == nil)
		var requestVerb = (isNewResource) ? "POST" : "PUT"
		var URL: NSURL
		var payload: NSData
		
		if isNewResource {
			URL = router.URLForResourceType(resource.type)
			payload = serializer.serializeResources([resource], options: SerializationOptions(includeID: false, dirtyFieldsOnly: false, includeToOne: true, includeToMany: true))
		} else {
			URL = router.URLForQuery(Query(resource: resource))
			payload = serializer.serializeResources([resource])
		}
		
		Spine.logInfo(.Spine, "Saving resource \(resource) using URL: \(URL)")
		
		_HTTPClient.request(requestVerb, URL: URL, payload: payload) { statusCode, responseData, error in
			if let error = error {
				promise.failure(self.handleErrorResponse(statusCode, responseData: responseData, error: error))
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
					Spine.logError(.Spine, "Error updating resource relationships: \(error)")
					promise.failure(error)
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
		
		typealias Operation = (relationship: Relationship, type: String, resources: [ResourceProtocol])
		
		var operations: [Operation] = []
		
		// Create operations
		enumerateFields(resource) { field in
			switch field {
			case let toOne as ToOneRelationship:
				let linkedResource = resource.valueForField(toOne.name) as ResourceProtocol
				if linkedResource.id != nil {
					operations.append((relationship: toOne, type: "replace", resources: [linkedResource]))
				}
			case let toMany as ToManyRelationship:
				let linkedResources = resource.valueForField(toMany.name) as LinkedResourceCollection
				operations.append((relationship: toMany, type: "add", resources: linkedResources.addedResources))
				operations.append((relationship: toMany, type: "remove", resources: linkedResources.removedResources))
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
					promise.failure(error)
					stop = true
				}
			case "remove":
				self.removeRelatedResources(operation.resources, fromResource: resource, relationship: operation.relationship).onFailure { error in
					promise.failure(error)
					stop = true
				}
			case "replace":
				self.setRelatedResource(operation.resources.first!, ofResource: resource, relationship: operation.relationship).onFailure { error in
					promise.failure(error)
					stop = true
				}
			default: ()
			}
		}
		
		return promise.future
	}
	
	private func addRelatedResources(resources: [ResourceProtocol], toResource: ResourceProtocol, relationship: Relationship) -> Future<Void> {
		let promise = Promise<Void>()
		
		if resources.count == 0 {
			promise.success()
		} else {
			let linkage: [[String: String]] = resources.map { resource in
				assert(resource.id != nil, "Attempt to relate resource without id. Only existing resources can be related.")
				return [resource.type: resource.id!]
			}
			
			let URL = self.router.URLForRelationship(relationship, ofResource: toResource)
			let jsonPayload = NSJSONSerialization.dataWithJSONObject(["data": linkage], options: NSJSONWritingOptions(0), error: nil)
			// TODO: Move serialization
			
			_HTTPClient.request("POST", URL: URL, payload: jsonPayload) { statusCode, responseData, error in
				if let error = error {
					promise.failure(self.handleErrorResponse(statusCode, responseData: responseData, error: error))
				} else {
					promise.success()
				}
			}
		}
		
		return promise.future
	}
	
	private func removeRelatedResources(resources: [ResourceProtocol], fromResource: ResourceProtocol, relationship: Relationship) -> Future<Void> {
		let promise = Promise<Void>()
		
		if resources.count == 0 {
			promise.success()
		} else {
			let linkage: [[String: String]] = resources.map { (resource) in
				assert(resource.id != nil, "Attempt to unrelate resource without id. Only existing resources can be unrelated.")
				return [resource.type: resource.id!]
			}
			
			let URL = router.URLForRelationship(relationship, ofResource: fromResource)
			let jsonPayload = NSJSONSerialization.dataWithJSONObject(["data": linkage], options: NSJSONWritingOptions(0), error: nil)
			// TODO: Move serialization
			
			_HTTPClient.request("DELETE", URL: URL) { statusCode, responseData, error in
				if let error = error {
					promise.failure(self.handleErrorResponse(statusCode, responseData: responseData, error: error))
				} else {
					promise.success()
				}
			}
		}
		
		return promise.future
	}
	
	private func setRelatedResource(resource: ResourceProtocol, ofResource: ResourceProtocol, relationship: Relationship) -> Future<Void> {
		let promise = Promise<Void>()
		
		let URL = router.URLForRelationship(relationship, ofResource: ofResource)
		
		let payload = ["data": [resource.type: resource.id!]]
		let jsonPayload = NSJSONSerialization.dataWithJSONObject(payload, options: NSJSONWritingOptions(0), error: nil)
		// TODO: Move serialization
		
		_HTTPClient.request("PATCH", URL: URL, payload: jsonPayload) { statusCode, responseData, error in
			if let error = error {
				promise.failure(self.handleErrorResponse(statusCode, responseData: responseData, error: error))
			} else {
				promise.success()
			}
		}
		
		return promise.future
	}
	
	
	// MARK: Deleting
	
	private func deleteResource(resource: ResourceProtocol) -> Future<Void> {
		let promise = Promise<Void>()
		let URL = self.router.URLForQuery(Query(resource: resource))
		
		Spine.logInfo(.Spine, "Deleting resource \(resource) using URL: \(URL)")
		
		_HTTPClient.request("DELETE", URL: URL) { statusCode, responseData, error in
			if let error = error {
				promise.failure(self.handleErrorResponse(statusCode, responseData: responseData, error: error))
			} else {
				promise.success()
			}
		}
		
		return promise.future
	}
}


// MARK: - Public functions

/**
Extension regarding (registering of) resource types.
*/
public extension Spine {
	/**
	Registers a factory function `factory` for resource type `type`.
	
	:param: type    The resource type to register the factory function for.
	:param: factory The factory method that returns an instance of a resource.
	*/
	func registerResource(type: String, factory: () -> ResourceProtocol) {
		serializer.resourceFactory.registerResource(type, factory: factory)
	}
}


/**
Extension regarding (registering of) transformers.
*/
public extension Spine {
	/**
	Registers transformer `transformer`.
	
	:param: type The Transformer to register.
	*/
	func registerTransformer<T: Transformer>(transformer: T) {
		serializer.transformers.registerTransformer(transformer)
	}
}

/**
Extension regarding finding resources.
*/
public extension Spine {
	/**
	Fetch multiple resources with the given IDs and type.
	
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
	
	:param: type The type of resource to fetch.
	
	:returns: A future that resolves to a ResourceCollection that contains the fetched resources.
	*/
	func find<T: ResourceProtocol>(type: T.Type) -> Future<ResourceCollection> {
		let query = Query(resourceType: type)
		return fetchResourcesByExecutingQuery(query)
	}
	
	/**
	Fetch one resource with the given ID and type.
	
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
	
	:param: query The query describing which resources to fetch.
	
	:returns: A future that resolves to a ResourceCollection that contains the fetched resources.
	*/
	func find<T: ResourceProtocol>(query: Query<T>) -> Future<ResourceCollection> {
		return fetchResourcesByExecutingQuery(query)
	}

	/**
	Fetch one resource using the given query.
	
	:param: query The query describing which resource to fetch.
	
	:returns: A future that resolves to the fetched resource.
	*/
	func findOne<T: ResourceProtocol>(query: Query<T>) -> Future<T> {
		let promise = Promise<T>()
		
		fetchResourcesByExecutingQuery(query).onSuccess { resourceCollection in
			if let resource = resourceCollection.resources.first as? T {
				promise.success(resource)
			} else {
				promise.failure(NSError(domain: SpineClientErrorDomain, code: 404, userInfo: nil))
			}
		}.onFailure { error in
			promise.failure(error)
		}
		
		return promise.future
	}
}

/**
Extension regarding persisting resources.
*/
public extension Spine {
	func save(resource: ResourceProtocol) -> Future<ResourceProtocol> {
		return saveResource(resource)
	}
	
	func delete(resource: ResourceProtocol) -> Future<Void> {
		return deleteResource(resource)
	}
}

/**
Extension regarding ensuring resources.
*/
public extension Spine {
	
	/**
	Ensures that the given resource is loaded. If it's `isLoaded` property is false,
	it loads the given resource from the API, otherwise it returns the resource as is.
	
	:param: resource The resource to ensure.
	
	:returns: <#return value description#>
	*/
	func ensure<T: ResourceProtocol>(resource: T) -> Future<T> {
		let query = Query(resource: resource)
		return loadResourceByExecutingQuery(resource, query: query)
	}

	/**
	Ensures that the given resource is loaded. If it's `isLoaded` property is false,
	it loads the given resource from the API, otherwise it returns the resource as is.
	
	:param: resource The resource to ensure.
	
	:param: resource      <#resource description#>
	:param: queryCallback <#queryCallback description#>
	
	:returns: <#return value description#>
	*/
	func ensure<T: ResourceProtocol>(resource: T, queryCallback: (Query<T>) -> Query<T>) -> Future<T> {
		let query = queryCallback(Query(resource: resource))
		return loadResourceByExecutingQuery(resource, query: query)
	}
}


// MARK: - Utilities

/// Return an `Array` containing resources of `domain`,
/// in order, that are of the resource type `type`.
func findResourcesWithType<C: CollectionType where C.Generator.Element: ResourceProtocol>(domain: C, type: ResourceType) -> [C.Generator.Element] {
	return filter(domain) { $0.type == type }
}

/// Return the first resource of `domain`,
/// that is of the resource type `type` and has id `id`.
func findResource<C: CollectionType where C.Generator.Element: ResourceProtocol>(domain: C, type: ResourceType, id: String) -> C.Generator.Element? {
	return filter(domain) { $0.type == type && $0.id == id }.first
}

/// Calls `callback` for each field, filtered by type `type`, of resource `resource`.
func enumerateFields<T: Field>(resource: ResourceProtocol, type: T.Type, callback: (T) -> ()) {
	enumerateFields(resource) { field in
		if let attribute = field as? T {
			callback(attribute)
		}
	}
}

func enumerateFields<T: ResourceProtocol>(resource: T, callback: (Field) -> ()) {
	for field in resource.dynamicType.fields {
		callback(field)
	}
}


/// Compare resources based on `type` and `id`.
public func == <T: ResourceProtocol> (left: T, right: T) -> Bool {
	return (left.id == right.id) && (left.type == right.type)
}

/// Compare array of resources based on `type` and `id`.
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

/// Sets all fields of resource `resource` to nil and sets `isLoaded` to false.
public func unloadResource(resource: ResourceProtocol) {
	enumerateFields(resource) { field in
		resource.setValue(nil, forField: field.name)
	}
	
	resource.isLoaded = false
}


// MARK: - Logging

public enum LogLevel: Int {
	case Debug = 0
	case Info = 1
	case Warning = 2
	case Error = 3
	case None = 4
	
	var description: String {
		switch self {
		case .Debug:   return "❔ Debug  "
		case .Info:    return "❕ Info   "
		case .Warning: return "❗️ Warning"
		case .Error:   return "❌ Error  "
		case .None:    return "None      "
		}
	}
}

/**
Logging domains

- Spine:       The main Spine component
- Networking:  The networking component, requests, responses etc
- Serializing: The (de)serializing component
*/
public enum LogDomain {
	case Spine, Networking, Serializing
}

/// Configured log levels
internal var logLevels: [LogDomain: LogLevel] = [
	.Spine: .None,
	.Networking: .None,
	.Serializing: .None
]

/**
Extension regarding logging.
*/
extension Spine {
	public class func setLogLevel(level: LogLevel, forDomain domain: LogDomain) {
		logLevels[domain] = level
	}
	
	class func shouldLog(level: LogLevel, domain: LogDomain) -> Bool {
		return (level.rawValue >= logLevels[domain]?.rawValue)
	}
	
	class func log<T>(object: T, level: LogLevel, domain: LogDomain) {
		if shouldLog(level, domain: domain) {
			println("\(level.description) - \(object)")
		}
	}
	
	class func logDebug<T>(domain: LogDomain, _ object: T) {
		log(object, level: .Debug, domain: domain)
	}
	
	class func logInfo<T>(domain: LogDomain, _ object: T) {
		log(object, level: .Info, domain: domain)
	}
	
	class func logWarning<T>(domain: LogDomain, _ object: T) {
		log(object, level: .Warning, domain: domain)
	}
	
	class func logError<T>(domain: LogDomain, _ object: T) {
		log(object, level: .Error, domain: domain)
	}
}


// MARK: - Futures

extension Future {
	func onServerFailure(callback: FailureCallback) -> BrightFutures.Future<T> {
		self.onFailure { error in
			if error.domain == SpineServerErrorDomain {
				callback(error)
			}
		}
		
		return self
	}
	
	func onNetworkFailure(callback: FailureCallback) -> BrightFutures.Future<T> {
		self.onFailure { error in
			if error.domain == NSURLErrorDomain {
				callback(error)
			}
		}
		
		return self
	}
	
	func onClientFailure(callback: FailureCallback) -> BrightFutures.Future<T> {
		self.onFailure { error in
			if error.domain == SpineClientErrorDomain {
				callback(error)
			}
		}
		
		return self
	}
}