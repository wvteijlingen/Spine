//
//  Resource.swift
//  Spine
//
//  Created by Ward van Teijlingen on 21-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation
import BrightFutures

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
	let serializer: JSONSerializer = JSONSerializer()
	
	/// The operation queue on which all operations are queued.
	let operationQueue = NSOperationQueue()
	
	
	// MARK: Initializers
	
	public init(baseURL: NSURL, router: RouterProtocol) {
		self.router = router
		self.router.baseURL = baseURL
		self.operationQueue.name = "com.wardvanteijlingen.spine"
	}
	
	public convenience init(baseURL: NSURL) {
		self.init(baseURL: baseURL, router: Router())
	}
	
	
	// MARK: Operations
	
	/**
	Adds the given operation to the operation queue.
	This sets the spine property of the operation to this Spine instance.
	
	:param: operation The operation to enqueue.
	*/
	func addOperation(operation: Operation) {
		operation.spine = self
		operationQueue.addOperation(operation)
	}
	
	
	// MARK: Fetching
	
	/**
	Fetch multiple resources using the given query..
	
	:param: query The query describing which resources to fetch.
	
	:returns: A future that resolves to a ResourceCollection that contains the fetched resources.
	*/
	public func find<T: ResourceProtocol>(query: Query<T>) -> Future<ResourceCollection> {
		let promise = Promise<ResourceCollection>()
		
		let operation = FetchOperation(query: query)
		
		operation.completionBlock = {
			if let error = operation.error {
				promise.failure(error)
			} else {
				promise.success(operation.result!)
			}
		}
		
		addOperation(operation)
		
		return promise.future
	}
	
	/**
	Fetch one resource using the given query.
	
	:param: query The query describing which resource to fetch.
	
	:returns: A future that resolves to the fetched resource.
	*/
	public func findOne<T: ResourceProtocol>(query: Query<T>) -> Future<T> {
		let promise = Promise<T>()
		
		let operation = FetchOperation(query: query)
		
		operation.completionBlock = {
			if let error = operation.error {
				promise.failure(error)
			} else if let resource = operation.result?.resources.first as? T {
				promise.success(resource)
			} else {
				promise.failure(NSError(domain: SpineClientErrorDomain, code: SpineErrorCodes.ResourceNotFound, userInfo: nil))
			}
		}
		
		addOperation(operation)
		
		return promise.future
	}
	
	/**
	Fetch multiple resources with the given IDs and type.
	
	:param: IDs  IDs of resources to fetch.
	:param: type The type of resource to fetch.
	
	:returns: A future that resolves to a ResourceCollection that contains the fetched resources.
	*/
	public func find<T: ResourceProtocol>(IDs: [String], ofType type: T.Type) -> Future<ResourceCollection> {
		let query = Query(resourceType: type, resourceIDs: IDs)
		return find(query)
	}
	
	/**
	Fetch all resources with the given type.
	This does not explicitly impose any limit, but the server may choose to limit the response.
	
	:param: type The type of resource to fetch.
	
	:returns: A future that resolves to a ResourceCollection that contains the fetched resources.
	*/
	public func find<T: ResourceProtocol>(type: T.Type) -> Future<ResourceCollection> {
		let query = Query(resourceType: type)
		return find(query)
	}
	
	/**
	Fetch one resource with the given ID and type.
	
	:param: ID   ID of resource to fetch.
	:param: type The type of resource to fetch.
	
	:returns: A future that resolves to the fetched resource.
	*/
	public func findOne<T: ResourceProtocol>(ID: String, ofType type: T.Type) -> Future<T> {
		let query = Query(resourceType: type, resourceIDs: [ID])
		return findOne(query)
	}
	
	
	// MARK: Persisting
	
	public func save(resource: ResourceProtocol) -> Future<ResourceProtocol> {
		let promise = Promise<ResourceProtocol>()
		
		let operation = SaveOperation(resource: resource)
		
		operation.completionBlock = {
			if let error = operation.error {
				promise.failure(error)
			} else {
				promise.success(resource)
			}
		}
		
		addOperation(operation)
		
		return promise.future
	}
	
	public func delete(resource: ResourceProtocol) -> Future<Void> {
		let promise = Promise<Void>()
		
		let operation = DeleteOperation(resource: resource)
		
		operation.completionBlock = {
			if let error = operation.error {
				promise.failure(error)
			} else {
				promise.success()
			}
		}
		
		addOperation(operation)
		
		return promise.future
	}
	
	
	// MARK: Ensuring
	
	/**
	Ensures that the given resource is loaded. If it's `isLoaded` property is false,
	it loads the given resource from the API, otherwise it returns the resource as is.
	
	:param: resource The resource to ensure.
	
	:returns: <#return value description#>
	*/
	public func ensure<T: ResourceProtocol>(resource: T) -> Future<T> {
		let query = Query(resource: resource)
		return loadResourceByExecutingQuery(resource, query: query)
	}
	
	/**
	Ensures that the given resource is loaded. If it's `isLoaded` property is false,
	it loads the given resource from the API, otherwise it returns the resource as is.
	
	:param: resource The resource to ensure.
	
	:param: resource      The resource to ensure.
	:param: queryCallback <#queryCallback description#>
	
	:returns: <#return value description#>
	*/
	public func ensure<T: ResourceProtocol>(resource: T, queryCallback: (Query<T>) -> Query<T>) -> Future<T> {
		let query = queryCallback(Query(resource: resource))
		return loadResourceByExecutingQuery(resource, query: query)
	}

	
	func loadResourceByExecutingQuery<T: ResourceProtocol>(resource: T, query: Query<T>) -> Future<T> {
		let promise = Promise<(T)>()
		
		if resource.isLoaded {
			promise.success(resource)
			return promise.future
		}
		
		let operation = FetchOperation(query: query)
		operation.mappingTargets = [resource]
		operation.completionBlock = {
			if let error = operation.error {
				promise.failure(error)
			} else {
				promise.success(resource)
			}
		}
		
		addOperation(operation)
		
		return promise.future
	}
}


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