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
	public func find<T: Resource>(query: Query<T>) -> Future<(resources: ResourceCollection, meta: [String: AnyObject]?, jsonapi: [String: AnyObject]?), NSError> {
		let promise = Promise<(resources: ResourceCollection, meta: [String: AnyObject]?, jsonapi: [String: AnyObject]?), NSError>()
		
		let operation = FetchOperation(query: query)
		
		operation.completionBlock = {

			switch operation.result! {
			case .Success(let document):
				let response = (ResourceCollection(document: document), document.meta, document.jsonapi)
				promise.success(response)
			case .Failure(let error):
				promise.failure(error)
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
	public func findOne<T: Resource>(query: Query<T>) -> Future<(resource: T, meta: [String: AnyObject]?, jsonapi: [String: AnyObject]?), NSError> {
		let promise = Promise<(resource: T, meta: [String: AnyObject]?, jsonapi: [String: AnyObject]?), NSError>()
		
		let operation = FetchOperation(query: query)
		
		operation.completionBlock = {
			switch operation.result! {
			case .Success(let document) where document.data?.count == 0:
				promise.failure(NSError(domain: SpineClientErrorDomain, code: SpineErrorCodes.ResourceNotFound, userInfo: nil))
			case .Success(let document):
				let firstResource = document.data!.first as! T
				let response = (resource: firstResource, meta: document.meta, jsonapi: document.jsonapi)
				promise.success(response)
			case .Failure(let error):
				promise.failure(error)
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
	public func find<T: Resource>(IDs: [String], ofType type: T.Type) -> Future<(resources: ResourceCollection, meta: [String: AnyObject]?, jsonapi: [String: AnyObject]?), NSError> {
		let query = Query(resourceType: type, resourceIDs: IDs)
		return find(query)
	}
	
	/**
	Fetch all resources with the given type.
	This does not explicitly impose any limit, but the server may choose to limit the response.
	
	:param: type The type of resource to fetch.
	
	:returns: A future that resolves to a ResourceCollection that contains the fetched resources.
	*/
	public func find<T: Resource>(type: T.Type) -> Future<(resources: ResourceCollection, meta: [String: AnyObject]?, jsonapi: [String: AnyObject]?), NSError> {
		let query = Query(resourceType: type)
		return find(query)
	}
	
	/**
	Fetch one resource with the given ID and type.
	
	:param: ID   ID of resource to fetch.
	:param: type The type of resource to fetch.
	
	:returns: A future that resolves to the fetched resource.
	*/
	public func findOne<T: Resource>(ID: String, ofType type: T.Type) -> Future<(resource: T, meta: [String: AnyObject]?, jsonapi: [String: AnyObject]?), NSError> {
		let query = Query(resourceType: type, resourceIDs: [ID])
		return findOne(query)
	}
	
	
	// MARK: Paginating
	
	/**
	Loads the next page of the given resource collection. The newly loaded resources are appended to the passed collection.
	When the next page is not available, the returned future will fail with a `NextPageNotAvailable` error code.
	
	:param: collection The collection for which to load the next page.
	
	:returns: A future that resolves to the ResourceCollection including the newly loaded resources.
	*/
	public func loadNextPageOfCollection(collection: ResourceCollection) -> Future<ResourceCollection, NSError> {
		let promise = Promise<ResourceCollection, NSError>()
		
		if let nextURL = collection.nextURL {
			let query = Query(URL: nextURL)
			let operation = FetchOperation(query: query)
			
			operation.completionBlock = {
				switch operation.result! {
				case .Success(let document):
					let nextCollection = ResourceCollection(document: document)
					collection.resources += nextCollection.resources
					collection.resourcesURL = nextCollection.resourcesURL
					collection.nextURL = nextCollection.nextURL
					collection.previousURL = nextCollection.previousURL
					
					promise.success(collection)
				case .Failure(let error):
					promise.failure(error)
				}
			}
			
			addOperation(operation)
			
		} else {
			promise.failure(NSError(domain: SpineClientErrorDomain, code: SpineErrorCodes.NextPageNotAvailable, userInfo: nil))
		}
		
		return promise.future
	}
	
	/**
	Loads the previous page of the given resource collection. The newly loaded resources are prepended to the passed collection.
	When the previous page is not available, the returned future will fail with a `PreviousPageNotAvailable` error code.
	
	:param: collection The collection for which to load the previous page.
	
	:returns: A future that resolves to the ResourceCollection including the newly loaded resources.
	*/
	public func loadPreviousPageOfCollection(collection: ResourceCollection) -> Future<ResourceCollection, NSError> {
		let promise = Promise<ResourceCollection, NSError>()
		
		if let previousURL = collection.previousURL {
			let query = Query(URL: previousURL)
			let operation = FetchOperation(query: query)
			
			operation.completionBlock = {
				switch operation.result! {
				case .Success(let document):
					let previousCollection = ResourceCollection(document: document)
					collection.resources = previousCollection.resources + collection.resources
					collection.resourcesURL = previousCollection.resourcesURL
					collection.nextURL = previousCollection.nextURL
					collection.previousURL = previousCollection.previousURL
					
					promise.success(collection)
				case .Failure(let error):
					promise.failure(error)
				}
			}

			addOperation(operation)
			
		} else {
			promise.failure(NSError(domain: SpineClientErrorDomain, code: SpineErrorCodes.PreviousPageNotAvailable, userInfo: nil))
		}
		
		return promise.future
	}
	
	
	// MARK: Persisting
	
	/**
	Saves the given resource.
	
	:param: resource The resource to save.
	
	:returns: A future that resolves to the saved resource.
	*/
	public func save(resource: Resource) -> Future<Resource, NSError> {
		let promise = Promise<Resource, NSError>()
		
		let operation = SaveOperation(resource: resource)
		
		operation.completionBlock = {
			if let error = operation.result?.error {
				promise.failure(error)
			} else {
				promise.success(resource)
			}
		}
		
		addOperation(operation)
		
		return promise.future
	}
	
	/**
	Deletes the given resource.
	
	:param: resource The resource to delete.
	
	:returns: A future
	*/
	public func delete(resource: Resource) -> Future<Void, NSError> {
		let promise = Promise<Void, NSError>()
		
		let operation = DeleteOperation(resource: resource)
		
		operation.completionBlock = {
			if let error = operation.result?.error {
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
	public func ensure<T: Resource>(resource: T) -> Future<T, NSError> {
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
	public func ensure<T: Resource>(resource: T, queryCallback: (Query<T>) -> Query<T>) -> Future<T, NSError> {
		let query = queryCallback(Query(resource: resource))
		return loadResourceByExecutingQuery(resource, query: query)
	}

	func loadResourceByExecutingQuery<T: Resource>(resource: T, query: Query<T>) -> Future<T, NSError> {
		let promise = Promise<(T), NSError>()
		
		if resource.isLoaded {
			promise.success(resource)
			return promise.future
		}
		
		let operation = FetchOperation(query: query)
		operation.mappingTargets = [resource]
		operation.completionBlock = {
			if let error = operation.result?.error {
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
	func registerResource(type: String, factory: () -> Resource) {
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
func findResourcesWithType<C: CollectionType where C.Generator.Element: Resource>(domain: C, type: ResourceType) -> [C.Generator.Element] {
	return domain.filter { $0.type == type }
}

/// Return the first resource of `domain`,
/// that is of the resource type `type` and has id `id`.
func findResource<C: CollectionType where C.Generator.Element: Resource>(domain: C, type: ResourceType, id: String) -> C.Generator.Element? {
	return domain.filter { $0.type == type && $0.id == id }.first
}

/// Calls `callback` for each field, filtered by type `type`, of resource `resource`.
func enumerateFields<T: Field>(resource: Resource, type: T.Type, callback: (T) -> ()) {
	enumerateFields(resource) { field in
		if let attribute = field as? T {
			callback(attribute)
		}
	}
}

func enumerateFields<T: Resource>(resource: T, callback: (Field) -> ()) {
	for field in resource.dynamicType.fields {
		callback(field)
	}
}


/// Compare resources based on `type` and `id`.
public func == <T: Resource> (left: T, right: T) -> Bool {
	return (left.id == right.id) && (left.type == right.type)
}

/// Compare array of resources based on `type` and `id`.
public func == <T: Resource> (left: [T], right: [T]) -> Bool {
	if left.count != right.count {
		return false
	}
	
	for (index, resource) in left.enumerate() {
		if (resource.type != right[index].type) || (resource.id != right[index].id) {
			return false
		}
	}
	
	return true
}

/// Sets all fields of resource `resource` to nil and sets `isLoaded` to false.
public func unloadResource(resource: Resource) {
	enumerateFields(resource) { field in
		resource.setValue(nil, forField: field.name)
	}
	
	resource.isLoaded = false
}


// MARK: - Failable

/**
Represents the result of a failable operation.
To work around the unimplemented "non-fixed multi-payload enum layout"
compiler error, we have to box the success value.

- Success: The operation succeeded with the given result.
- Failure: The operation failed with the given error.
*/
enum Failable<T> {
	case Success(T)
	case Failure(NSError)
	
	init(_ value: T) {
		self = .Success(value)
	}
	
	init(_ error: NSError) {
		self = .Failure(error)
	}
	
	var error: NSError? {
		switch self {
		case .Failure(let error):
			return error
		default:
			return nil
		}
	}
}