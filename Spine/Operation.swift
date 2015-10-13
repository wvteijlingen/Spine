//
//  Operation.swift
//  Spine
//
//  Created by Ward van Teijlingen on 05-04-15.
//  Copyright (c) 2015 Ward van Teijlingen. All rights reserved.
//

import Foundation

private func statusCodeIsSuccess(statusCode: Int?) -> Bool {
	return statusCode != nil && 200 ... 299 ~= statusCode!
}

private func errorFromStatusCode(statusCode: Int, additionalErrors: [NSError]? = nil) -> NSError {
	let userInfo: [NSObject: AnyObject]?
	
	if let additionalErrors = additionalErrors {
		userInfo = ["apiErrors": additionalErrors]
	} else {
		userInfo = nil
	}
	
	return NSError(domain: SpineServerErrorDomain, code: statusCode, userInfo: userInfo)
}

/**
The Operation class is an abstract class for all Spine operations.
You must not create instances of this class directly, but instead create
an instance of one of its concrete subclasses.

Subclassing
===========
To support generic subclasses, Operation adds an `execute` method.
Override this method to provide the implementation for a concurrent subclass.

Concurrent state
================
Operation is concurrent by default. To update the state of the operation,
update the `state` instance variable. This will fire off the needed KVO notifications.

Operating against a Spine
=========================
The `Spine` instance variable references the Spine against which to operate.
If you add this operation using the Spine `addOperation` method, the variable
will be set for you. Otherwise, you need to set it yourself.
*/
class Operation: NSOperation {
	/// The Spine instance to operate against.
	var spine: Spine!
	
	/// Convenience variables that proxy to their spine counterpart
	var router: RouterProtocol {
		return spine.router
	}
	var networkClient: NetworkClient {
		return spine.networkClient
	}
	var serializer: JSONSerializer {
		return spine.serializer
	}
	
	override init() {}
	
	final override func start() {
		if self.cancelled {
			state = .Finished
		} else {
			state = .Executing
			main()
		}
	}
	
	final override func main() {
		execute()
	}
	
	func execute() {}
	
	
	// MARK: Concurrency

	enum State: String {
		case Ready = "isReady"
		case Executing = "isExecuting"
		case Finished = "isFinished"
	}

	/// The current state of the operation
	var state: State = .Ready {
		willSet {
			willChangeValueForKey(newValue.rawValue)
			willChangeValueForKey(state.rawValue)
		}
		didSet {
			didChangeValueForKey(oldValue.rawValue)
			didChangeValueForKey(state.rawValue)
		}
	}
	override var ready: Bool {
		return super.ready && state == .Ready
	}
	override var executing: Bool {
		return state == .Executing
	}
	override var finished: Bool {
		return state == .Finished
	}
	override var asynchronous: Bool {
		return true
	}
}

/**
A FetchOperation object fetches a JSONAPI document from a Spine, using a given Query.
*/
class FetchOperation<T: Resource>: Operation {
	/// The query describing which resources to fetch.
	let query: Query<T>
	
	/// Existing resources onto which to map the fetched resources.
	var mappingTargets = [Resource]()
	
	/// The result of the operation. You can safely force unwrap this in the completionBlock.
	var result: Failable<JSONAPIDocument>?
	
	init(query: Query<T>) {
		self.query = query
		super.init()
	}
	
	override func execute() {
		let URL = spine.router.URLForQuery(query)
		
		Spine.logInfo(.Spine, "Fetching document using URL: \(URL)")
		
		networkClient.request("GET", URL: URL) { statusCode, responseData, networkError in
			defer { self.state = .Finished }
			
			guard networkError == nil else {
				self.result = Failable.Failure(networkError!)
				return
			}
			
			if let data = responseData where data.length > 0 {
				do {
					let document = try self.serializer.deserializeData(data, mappingTargets: self.mappingTargets)
					if statusCodeIsSuccess(statusCode) {
						self.result = Failable(document)
					} else {
						self.result = Failable.Failure(errorFromStatusCode(statusCode!, additionalErrors: document.errors))
					}
				} catch let error as NSError {
					self.result = Failable.Failure(error)
				}
				
			} else {
				self.result = Failable.Failure(errorFromStatusCode(statusCode!))
			}
		}
	}
}

/**
A DeleteOperation deletes a resource from a Spine.
*/
class DeleteOperation: Operation {
	/// The resource to delete.
	let resource: Resource
	
	/// The result of the operation. You can safely force unwrap this in the completionBlock.
	var result: Failable<Void>?
	
	init(resource: Resource) {
		self.resource = resource
		super.init()
	}
	
	override func execute() {
		let URL = spine.router.URLForQuery(Query(resource: resource))
		
		Spine.logInfo(.Spine, "Deleting resource \(resource) using URL: \(URL)")
		
		networkClient.request("DELETE", URL: URL) { statusCode, responseData, networkError in
			defer { self.state = .Finished }
		
			guard networkError == nil else {
				self.result = Failable.Failure(networkError!)
				return
			}
			
			if statusCodeIsSuccess(statusCode) {
				self.result = Failable.Success()
			} else if let data = responseData where data.length > 0 {
				do {
					let document = try self.serializer.deserializeData(data, mappingTargets: nil)
					self.result = .Failure(errorFromStatusCode(statusCode!, additionalErrors: document.errors))
				} catch let error as NSError {
					self.result = .Failure(error)
				}
			} else {
				self.result = .Failure(errorFromStatusCode(statusCode!))
			}
		}
	}
}

/**
A SaveOperation saves a resources in a Spine. It can be used to either update an existing resource,
or to insert new resources.
*/
class SaveOperation: Operation {
	/// The resource to save.
	let resource: Resource
	
	/// The result of the operation. You can safely force unwrap this in the completionBlock.
	var result: Failable<Void>?
	
	/// Whether the resource is a new resource, or an existing resource.
	private let isNewResource: Bool
	
	init(resource: Resource) {
		self.resource = resource
		self.isNewResource = (resource.id == nil)
		super.init()
	}
	
	override func execute() {
		let URL: NSURL, method: String, payload: NSData

		if isNewResource {
			URL = router.URLForResourceType(resource.type)
			method = "POST"
			payload = serializer.serializeResources([resource], options: SerializationOptions(includeID: false, dirtyFieldsOnly: false, includeToOne: true, includeToMany: true))
		} else {
			URL = router.URLForQuery(Query(resource: resource))
			method = "PUT"
			payload = serializer.serializeResources([resource])
		}
		
		Spine.logInfo(.Spine, "Saving resource \(resource) using URL: \(URL)")
		
		networkClient.request(method, URL: URL, payload: payload) { statusCode, responseData, networkError in
			defer { self.state = .Finished }
			
			guard networkError == nil else {
				self.result = Failable.Failure(networkError!)
				return
			}

			if(!statusCodeIsSuccess(statusCode)) {
				if let data = responseData where data.length > 0 {
					do {
						let document = try self.serializer.deserializeData(data, mappingTargets: nil)
						self.result = .Failure(errorFromStatusCode(statusCode!, additionalErrors: document.errors))
						return
					} catch let error as NSError {
						self.result = .Failure(error)
						return
					}
				} else {
					self.result = .Failure(errorFromStatusCode(statusCode!))
					return
				}
				
			} else {
				if let data = responseData where data.length > 0 {
					do {
						try self.serializer.deserializeData(data, mappingTargets: [self.resource])
					} catch let error as NSError {
						self.result = .Failure(error)
						return
					}
				} else {
					self.result = .Failure(errorFromStatusCode(statusCode!))
					return
				}
			}
			
			// Separately update relationships if this is an existing resource
			if self.isNewResource {
				self.result = Failable.Success()
			} else {
				let relationshipOperation = RelationshipOperation(resource: self.resource)
				
				relationshipOperation.completionBlock = {
					if let error = relationshipOperation.result?.error {
						self.result = Failable(error)
					}
				}
				
				relationshipOperation.execute()
			}
		}
	}
}

/**
A SaveOperation updates the relationships of a given resource.
It will add and remove resources to and from many-to-many relationships, and update to-one relationships.
*/
class RelationshipOperation: Operation {
	/// The resource for which to save the relationships.
	let resource: Resource
	
	/// The result of the operation. You can safely force unwrap this in the completionBlock.
	var result: Failable<Void>?
	
	init(resource: Resource) {
		self.resource = resource
		super.init()
	}
	
	override func execute() {
		// TODO: Where do we call success here?
		typealias Operation = (relationship: Relationship, type: String, resources: [Resource])
		var operations: [Operation] = []
		
		// Create operations
		enumerateFields(resource) { field in
			switch field {
			case let toOne as ToOneRelationship:
				let linkedResource = self.resource.valueForField(toOne.name) as! Resource
				if linkedResource.id != nil {
					operations.append((relationship: toOne, type: "replace", resources: [linkedResource]))
				}
			case let toMany as ToManyRelationship:
				let linkedResources = self.resource.valueForField(toMany.name) as! LinkedResourceCollection
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
				self.addRelatedResources(operation.resources, relationship: operation.relationship) { error in
					if let error = error {
						self.result = Failable(error)
						stop = true
					}
				}
			case "remove":
				self.removeRelatedResources(operation.resources, relationship: operation.relationship) { error in
					if let error = error {
						self.result = Failable(error)
						stop = true
					}
				}
			case "replace":
				self.setRelatedResource(operation.resources.first!, relationship: operation.relationship) { error in
					if let error = error {
						self.result = Failable(error)
						stop = true
					}
				}
			default: ()
			}
		}
		
		self.state = .Finished
	}
	
	private func addRelatedResources(relatedResources: [Resource], relationship: Relationship, callback: (NSError?) -> ()) {
		if relatedResources.isEmpty {
			callback(nil)
			return
		}
		
		let jsonPayload = serializeLinkageToJSON(convertResourcesToLinkage(relatedResources)) // TODO: Move serialization
		let URL = self.router.URLForRelationship(relationship, ofResource: self.resource)
		
		self.networkClient.request("POST", URL: URL, payload: jsonPayload) { statusCode, responseData, networkError in
			if let networkError = networkError {
				callback(networkError)
			} else if(!statusCodeIsSuccess(statusCode)) {
				callback(errorFromStatusCode(statusCode!))
			} else {
				callback(nil)
			}
		}
	}
	
	private func removeRelatedResources(relatedResources: [Resource], relationship: Relationship, callback: (NSError?) -> ()) {
		if relatedResources.isEmpty {
			callback(nil)
			return
		}
	
		let URL = router.URLForRelationship(relationship, ofResource: self.resource)
		
		self.networkClient.request("DELETE", URL: URL) { statusCode, responseData, networkError in
			if let networkError = networkError {
				callback(networkError)
			} else if(!statusCodeIsSuccess(statusCode)) {
				callback(errorFromStatusCode(statusCode!))
			} else {
				callback(nil)
			}
		}
	}
	
	private func setRelatedResource(relatedResource: Resource, relationship: Relationship, callback: (NSError?) -> ()) {
		let URL = router.URLForRelationship(relationship, ofResource: self.resource)
		let jsonPayload = serializeLinkageToJSON(convertResourcesToLinkage([relatedResource])) // TODO: Move serialization
		
		networkClient.request("PATCH", URL: URL, payload: jsonPayload) { statusCode, responseData, networkError in
			if let networkError = networkError {
				callback(networkError)
			} else if(!statusCodeIsSuccess(statusCode)) {
				callback(errorFromStatusCode(statusCode!))
			} else {
				callback(nil)
			}
		}
	}
	
	private func convertResourcesToLinkage(resources: [Resource]) -> [[String: String]] {
		let linkage: [[String: String]] = resources.map { resource in
			assert(resource.id != nil, "Attempt to (un)relate resource without id. Only existing resources can be (un)related.")
			return [resource.type: resource.id!]
		}
		
		return linkage
	}
	
	private func serializeLinkageToJSON(linkage: [[String: String]]) -> NSData? {
		return try? NSJSONSerialization.dataWithJSONObject(["data": linkage], options: NSJSONWritingOptions(rawValue: 0))
	}
}