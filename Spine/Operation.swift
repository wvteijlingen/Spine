//
//  Operation.swift
//  Spine
//
//  Created by Ward van Teijlingen on 05-04-15.
//  Copyright (c) 2015 Ward van Teijlingen. All rights reserved.
//

import Foundation

fileprivate func statusCodeIsSuccess(_ statusCode: Int?) -> Bool {
	return statusCode != nil && 200 ... 299 ~= statusCode!
}

fileprivate extension Error {
	///  Promotes the rror to a SpineError.
	///  Errors that cannot be represented as a SpineError will be returned as SpineError.unknownError
	var asSpineError: SpineError {
		switch self {
		case is SpineError:
			return self as! SpineError
		case is SerializerError:
			return .serializerError(self as! SerializerError)
		default:
			return .unknownError
		}
	}
}


// MARK: - Base operation

/**
The ConcurrentOperation class is an abstract class for all Spine operations.
You must not create instances of this class directly, but instead create
an instance of one of its concrete subclasses.

Subclassing
===========
To support generic subclasses, Operation adds an `execute` method.
Override this method to provide the implementation for a concurrent subclass.

Concurrent state
================
ConcurrentOperation is concurrent by default. To update the state of the operation,
update the `state` instance variable. This will fire off the needed KVO notifications.

Operating against a Spine
=========================
The `Spine` instance variable references the Spine against which to operate.
*/
class ConcurrentOperation: Operation {
	enum State: String {
		case ready = "isReady"
		case executing = "isExecuting"
		case finished = "isFinished"
	}
	
	/// The current state of the operation
	var state: State = .ready {
		willSet {
			willChangeValue(forKey: newValue.rawValue)
			willChangeValue(forKey: state.rawValue)
		}
		didSet {
			didChangeValue(forKey: oldValue.rawValue)
			didChangeValue(forKey: state.rawValue)
		}
	}
	override var isReady: Bool {
		return super.isReady && state == .ready
	}
	override var isExecuting: Bool {
		return state == .executing
	}
	override var isFinished: Bool {
		return state == .finished
	}
	override var isAsynchronous: Bool {
		return true
	}
	
	/// The Spine instance to operate against.
	var spine: Spine!
	
	/// Convenience variables that proxy to their spine counterpart
	var router: Router {
		return spine.router
	}
	var networkClient: NetworkClient {
		return spine.networkClient
	}
	var serializer: Serializer {
		return spine.serializer
	}
	
	override init() {}
	
	final override func start() {
		if isCancelled {
			state = .finished
		} else {
			state = .executing
			main()
		}
	}
	
	final override func main() {
		execute()
	}
	
	func execute() {}
}


// MARK: - Main operations

/// FetchOperation fetches a JSONAPI document from a Spine, using a given Query.
class FetchOperation<T: Resource>: ConcurrentOperation {
	/// The query describing which resources to fetch.
	let query: Query<T>
	
	/// Existing resources onto which to map the fetched resources.
	var mappingTargets = [Resource]()
	
	/// The result of the operation. You can safely force unwrap this in the completionBlock.
	var result: Failable<JSONAPIDocument, SpineError>?
	
	init(query: Query<T>, spine: Spine) {
		self.query = query
		super.init()
		self.spine = spine
	}
	
	override func execute() {
		let url = spine.router.urlForQuery(query)
		
		Spine.logInfo(.spine, "Fetching document using URL: \(url)")
		
		networkClient.request(method: "GET", url: url) { statusCode, responseData, networkError in
			defer { self.state = .finished }
			
			guard networkError == nil else {
				self.result = .failure(.networkError(networkError!))
				return
			}
			
			if let data = responseData , data.count > 0 {
				do {
					let document = try self.serializer.deserializeData(data, mappingTargets: self.mappingTargets)
					if statusCodeIsSuccess(statusCode) {
						self.result = .success(document)
					} else {
						self.result = .failure(.serverError(statusCode: statusCode!, apiErrors: document.errors))
					}
				} catch let error {
					self.result = .failure(error.asSpineError)
				}
				
			} else {
				self.result = .failure(.serverError(statusCode: statusCode!, apiErrors: nil))
			}
		}
	}
}

/// DeleteOperation deletes a resource from a Spine.
class DeleteOperation: ConcurrentOperation {
	/// The resource to delete.
	let resource: Resource
	
	/// The result of the operation. You can safely force unwrap this in the completionBlock.
	var result: Failable<Void, SpineError>?
	
	init(resource: Resource, spine: Spine) {
		self.resource = resource
		super.init()
		self.spine = spine
	}
	
	override func execute() {
		let URL = spine.router.urlForQuery(Query(resource: resource))
		
		Spine.logInfo(.spine, "Deleting resource \(resource) using URL: \(URL)")
		
		networkClient.request(method: "DELETE", url: URL) { statusCode, responseData, networkError in
			defer { self.state = .finished }
		
			guard networkError == nil else {
				self.result = .failure(.networkError(networkError!))
				return
			}
			
			if statusCodeIsSuccess(statusCode) {
				self.result = .success()
			} else if let data = responseData , data.count > 0 {
				do {
					let document = try self.serializer.deserializeData(data)
					self.result = .failure(.serverError(statusCode: statusCode!, apiErrors: document.errors))
				} catch let error {
					self.result = .failure(error.asSpineError)
				}
			} else {
				self.result = .failure(.serverError(statusCode: statusCode!, apiErrors: nil))
			}
		}
	}
}

/// A SaveOperation updates or adds a resource in a Spine.
class SaveOperation: ConcurrentOperation {
	/// The resource to save.
	let resource: Resource
	
	/// The result of the operation. You can safely force unwrap this in the completionBlock.
	var result: Failable<Void, SpineError>?
	
	/// Whether the resource is a new resource, or an existing resource.
	fileprivate let isNewResource: Bool
	
	fileprivate let relationshipOperationQueue = OperationQueue()
	
	init(resource: Resource, spine: Spine) {
		self.resource = resource
		self.isNewResource = (resource.id == nil)
		super.init()
		self.spine = spine
		self.relationshipOperationQueue.maxConcurrentOperationCount = 1
		self.relationshipOperationQueue.addObserver(self, forKeyPath: "operations", context: nil)
	}
	
	deinit {
		self.relationshipOperationQueue.removeObserver(self, forKeyPath: "operations")
	}
	
	override func execute() {
		// First update relationships if this is an existing resource. Otherwise the local relationships
		// are overwritten with data that is returned from saving the resource.
		if isNewResource {
			updateResource()
		} else {
			updateRelationships()
		}
	}

	fileprivate func updateResource() {
		let url: URL
		let method: String
		let options: SerializationOptions
		
		if isNewResource {
			url = router.urlForResourceType(resource.resourceType)
			method = "POST"
			if let idGenerator = spine.idGenerator {
				resource.id = idGenerator(resource)
				options = [.IncludeToOne, .IncludeToMany, .IncludeID]
			} else {
				options = [.IncludeToOne, .IncludeToMany]
			}
		} else {
			url = router.urlForQuery(Query(resource: resource))
			method = "PATCH"
			options = [.IncludeID]
		}
		
		let payload: Data
		
		do {
			payload = try serializer.serializeResources([resource], options: options)
		} catch let error {
			result = .failure(error.asSpineError)
			state = .finished
			return
		}

		Spine.logInfo(.spine, "Saving resource \(resource) using URL: \(url)")
		
		networkClient.request(method: method, url: url, payload: payload) { statusCode, responseData, networkError in
			defer { self.state = .finished }
			
			if let error = networkError {
				self.result = .failure(.networkError(error))
				return
			}
			
			let success = statusCodeIsSuccess(statusCode)
			let document: JSONAPIDocument?
			if let data = responseData , data.count > 0 {
				do {
					// Don't map onto the resources if the response is not in the success range.
					let mappingTargets: [Resource]? = success ? [self.resource] : nil
					document = try self.serializer.deserializeData(data, mappingTargets: mappingTargets)
				} catch let error {
					self.result = .failure(error.asSpineError)
					return
				}
			} else {
				document = nil
			}
			
			if success {
				self.result = .success()
			} else {
				self.result = .failure(.serverError(statusCode: statusCode!, apiErrors: document?.errors))
			}
		}
	}
	
	/// Serializes `resource` into NSData using `options`. Any error that occurs is rethrown as a SpineError.
	fileprivate func serializePayload(_ resource: Resource, options: SerializationOptions) throws -> Data {
		do {
			let payload = try serializer.serializeResources([resource], options: options)
			return payload
		} catch let error {
			throw error.asSpineError
		}
	}

	fileprivate func updateRelationships() {
		let relationships = resource.fields.filter { field in
			return field is Relationship && !field.isReadOnly
		}
		
		guard !relationships.isEmpty else {
			updateResource()
			return
		}
		
		let completionHandler: (_ result: Failable<Void, SpineError>?) -> Void = { result in
			if let error = result?.error {
				self.relationshipOperationQueue.cancelAllOperations()
				self.result = .failure(error)
				self.state = .finished
			}
		}
		
		for relationship in relationships {
			switch relationship {
			case let toOne as ToOneRelationship:
				let operation = RelationshipReplaceOperation(resource: resource, relationship: toOne, spine: spine)
				operation.completionBlock = { [unowned operation] in completionHandler(operation.result) }
				relationshipOperationQueue.addOperation(operation)

			case let toMany as ToManyRelationship:
				let addOperation = RelationshipMutateOperation(resource: resource, relationship: toMany, mutation: .add, spine: spine)
				addOperation.completionBlock = { [unowned addOperation] in completionHandler(addOperation.result) }
				relationshipOperationQueue.addOperation(addOperation)
				
				let removeOperation = RelationshipMutateOperation(resource: resource, relationship: toMany, mutation: .remove, spine: spine)
				removeOperation.completionBlock = { [unowned removeOperation] in completionHandler(removeOperation.result) }
				relationshipOperationQueue.addOperation(removeOperation)
			default: ()
			}
		}
	}
	
	override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
		guard let path = keyPath, let queue = object as? OperationQueue , path == "operations" && queue == relationshipOperationQueue else {
			super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
			return
		}
		
		if queue.operationCount == 0 {
			// At this point, we know all relationships are updated
			updateResource()
		}
	}
}

private class RelationshipOperation: ConcurrentOperation {
	var result: Failable<Void, SpineError>?
	
	func handleNetworkResponse(_ statusCode: Int?, responseData: Data?, networkError: NSError?) {
		defer { self.state = .finished }
		
		guard networkError == nil else {
			self.result = .failure(.networkError(networkError!))
			return
		}
		
		if statusCodeIsSuccess(statusCode) {
			self.result = .success()
		} else if let data = responseData, data.count > 0 {
			do {
				let document = try serializer.deserializeData(data)
				self.result = .failure(.serverError(statusCode: statusCode!, apiErrors: document.errors))
			} catch let error {
				self.result = .failure(error.asSpineError)
			}
		} else {
			self.result = .failure(.serverError(statusCode: statusCode!, apiErrors: nil))
		}
	}
}

/// A RelationshipReplaceOperation replaces the entire contents of a relationship.
private class RelationshipReplaceOperation: RelationshipOperation {
	let resource: Resource
	let relationship: Relationship

	init(resource: Resource, relationship: Relationship, spine: Spine) {
		self.resource = resource
		self.relationship = relationship
		super.init()
		self.spine = spine
	}
	
	override func execute() {
		let url = router.urlForRelationship(relationship, ofResource: resource)
		let payload: Data
		
		switch relationship {
		case is ToOneRelationship:
			payload = try! serializer.serializeLinkData(resource.value(forField: relationship.name) as? Resource)
		case is ToManyRelationship:
			let relatedResources = (resource.value(forField: relationship.name) as? ResourceCollection)?.resources ?? []
			payload = try! serializer.serializeLinkData(relatedResources)
		default:
			assertionFailure("Cannot only replace relationship contents for ToOneRelationship and ToManyRelationship")
			return
		}

		Spine.logInfo(.spine, "Replacing relationship \(relationship) using URL: \(url)")
		networkClient.request(method: "PATCH", url: url, payload: payload, callback: handleNetworkResponse)
	}
}

/// A RelationshipMutateOperation mutates a to-many relationship by adding or removing linked resources.
private class RelationshipMutateOperation: RelationshipOperation {
	enum Mutation {
		case add, remove
	}
	
	let resource: Resource
	let relationship: ToManyRelationship
	let mutation: Mutation

	init(resource: Resource, relationship: ToManyRelationship, mutation: Mutation, spine: Spine) {
		self.resource = resource
		self.relationship = relationship
		self.mutation = mutation
		super.init()
		self.spine = spine
	}

	override func execute() {
		let resourceCollection = resource.value(forField: relationship.name) as! LinkedResourceCollection
		let httpMethod: String
		let relatedResources: [Resource]
		
		switch mutation {
		case .add:
			httpMethod = "POST"
			relatedResources = resourceCollection.addedResources
		case .remove:
			httpMethod = "DELETE"
			relatedResources = resourceCollection.removedResources
		}
		
		guard !relatedResources.isEmpty else {
			result = .success()
			state = .finished
			return
		}
		
		let url = router.urlForRelationship(relationship, ofResource: resource)
		let payload = try! serializer.serializeLinkData(relatedResources)
		Spine.logInfo(.spine, "Mutating relationship \(relationship) using URL: \(url)")
		networkClient.request(method: httpMethod, url: url, payload: payload, callback: handleNetworkResponse)
	}
}
