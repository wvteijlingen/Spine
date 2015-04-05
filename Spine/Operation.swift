//
//  Operation.swift
//  Spine
//
//  Created by Ward van Teijlingen on 05-04-15.
//  Copyright (c) 2015 Ward van Teijlingen. All rights reserved.
//

import Foundation

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
	var HTTPClient: _HTTPClientProtocol {
		return spine._HTTPClient
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
	
	func handleError(statusCode: Int?, responseData: NSData?, error: NSError) -> NSError {
		switch error.domain {
		case SpineServerErrorDomain:
			return serializer.deserializeError(responseData!, withResonseStatus: statusCode!)
		default:
			return error
		}
	}
	
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

class FetchOperation<T: ResourceProtocol>: Operation {
	let query: Query<T>
	var mappingTargets = [ResourceProtocol]()
	
	var result: ResourceCollection?
	var error: NSError?
	
	init(query: Query<T>) {
		self.query = query
		super.init()
	}
	
	override func execute() {
		let URL = spine.router.URLForQuery(query)
		
		Spine.logInfo(.Spine, "Fetching resources using URL: \(URL)")
		
		HTTPClient.request("GET", URL: URL) { statusCode, responseData, error in
			if let error = error {
				self.error = self.handleError(statusCode, responseData: responseData, error: error)
			} else {
				let deserializationResult = self.serializer.deserializeData(responseData!, mappingTargets: self.mappingTargets)
				
				switch deserializationResult {
				case .Success(let resources):
					self.result = ResourceCollection(resources: resources)
				case .Failure(let error):
					self.error = error
				}
			}
			
			self.state = .Finished
		}
	}
}

class DeleteOperation: Operation {
	let resource: ResourceProtocol

	var error: NSError?
	
	init(resource: ResourceProtocol) {
		self.resource = resource
		super.init()
	}
	
	override func execute() {
		let URL = spine.router.URLForQuery(Query(resource: resource))
		
		Spine.logInfo(.Spine, "Deleting resource \(resource) using URL: \(URL)")
		
		HTTPClient.request("DELETE", URL: URL) { statusCode, responseData, error in
			if let error = error {
				self.error = self.handleError(statusCode, responseData: responseData, error: error)
			}
			
			self.state = .Finished
		}
	}
}

class SaveOperation: Operation {
	let resource: ResourceProtocol
	var isNewResource: Bool {
		return resource.id == nil
	}
	
	var error: NSError?
	
	init(resource: ResourceProtocol) {
		self.resource = resource
		super.init()
	}
	
	override func execute() {
		let request = requestData()
		
		Spine.logInfo(.Spine, "Saving resource \(resource) using URL: \(request.URL)")
		
		HTTPClient.request(request.method, URL: request.URL, payload: request.payload) { statusCode, responseData, error in
			if let error = error {
				self.error = self.handleError(statusCode, responseData: responseData, error: error)
				self.state = .Finished
				return
			}
			
			// Map the response back onto the resource
			if let data = responseData {
				self.serializer.deserializeData(data, mappingTargets: [self.resource])
			}
			
			// Separately update relationships if this is an existing resource
			if self.isNewResource {
				self.state = .Finished
				return
			} else {
				let relationshipOperation = RelationshipOperation(resource: self.resource)
				
				relationshipOperation.completionBlock = {
					if let error = relationshipOperation.error {
						Spine.logError(.Spine, "Error updating resource relationships: \(error)")
						self.error = error
					}
					
					self.state = .Finished
				}
			}
		}
	}
	
	private func requestData() -> (URL: NSURL, method: String, payload: NSData) {
		if isNewResource {
			return (
				URL: router.URLForResourceType(resource.type),
				method: "POST",
				payload: serializer.serializeResources([resource], options: SerializationOptions(includeID: false, dirtyFieldsOnly: false, includeToOne: true, includeToMany: true))
			)
		} else {
			return (
				URL: router.URLForQuery(Query(resource: resource)),
				method: "PUT",
				payload: serializer.serializeResources([resource])
			)
		}
	}
}

class RelationshipOperation: Operation {
	let resource: ResourceProtocol
	
	var error: NSError?
	
	init(resource: ResourceProtocol) {
		self.resource = resource
		super.init()
	}
	
	override func execute() {
		// TODO: Where do we call success here?
		
		typealias Operation = (relationship: Relationship, type: String, resources: [ResourceProtocol])
		
		var operations: [Operation] = []
		
		// Create operations
		enumerateFields(resource) { field in
			switch field {
			case let toOne as ToOneRelationship:
				let linkedResource = self.resource.valueForField(toOne.name) as ResourceProtocol
				if linkedResource.id != nil {
					operations.append((relationship: toOne, type: "replace", resources: [linkedResource]))
				}
			case let toMany as ToManyRelationship:
				let linkedResources = self.resource.valueForField(toMany.name) as LinkedResourceCollection
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
						self.error = error
						stop = true
					}
				}
			case "remove":
				self.removeRelatedResources(operation.resources, relationship: operation.relationship) { error in
					if let error = error {
						self.error = error
						stop = true
					}
				}
			case "replace":
				self.setRelatedResource(operation.resources.first!, relationship: operation.relationship) { error in
					if let error = error {
						self.error = error
						stop = true
					}
				}
			default: ()
			}
		}
		
		self.state = .Finished
	}
	
	private func addRelatedResources(relatedResources: [ResourceProtocol], relationship: Relationship, callback: (NSError?) -> ()) {
		if relatedResources.count == 0 {
			callback(nil)
		} else {
			let linkage: [[String: String]] = relatedResources.map { resource in
				assert(resource.id != nil, "Attempt to relate resource without id. Only existing resources can be related.")
				return [resource.type: resource.id!]
			}
			
			let URL = self.router.URLForRelationship(relationship, ofResource: self.resource)
			let jsonPayload = NSJSONSerialization.dataWithJSONObject(["data": linkage], options: NSJSONWritingOptions(0), error: nil)
			// TODO: Move serialization
			
			self.HTTPClient.request("POST", URL: URL, payload: jsonPayload) { statusCode, responseData, error in
				if let error = error {
					callback(self.handleError(statusCode, responseData: responseData, error: error))
				} else {
					callback(nil)
				}
			}
		}
	}
	
	private func removeRelatedResources(relatedResources: [ResourceProtocol], relationship: Relationship, callback: (NSError?) -> ()) {
		if relatedResources.count == 0 {
			callback(nil)
		} else {
			let linkage: [[String: String]] = relatedResources.map { (resource) in
				assert(resource.id != nil, "Attempt to unrelate resource without id. Only existing resources can be unrelated.")
				return [resource.type: resource.id!]
			}
			
			let URL = router.URLForRelationship(relationship, ofResource: self.resource)
			let jsonPayload = NSJSONSerialization.dataWithJSONObject(["data": linkage], options: NSJSONWritingOptions(0), error: nil)
			// TODO: Move serialization
			
			self.HTTPClient.request("DELETE", URL: URL) { statusCode, responseData, error in
				if let error = error {
					callback(self.handleError(statusCode, responseData: responseData, error: error))
				} else {
					callback(nil)
				}
			}
		}
	}
	
	private func setRelatedResource(relatedResource: ResourceProtocol, relationship: Relationship, callback: (NSError?) -> ()) {
		let URL = router.URLForRelationship(relationship, ofResource: self.resource)
		let payload = ["data": [relatedResource.type: relatedResource.id!]]
		let jsonPayload = NSJSONSerialization.dataWithJSONObject(payload, options: NSJSONWritingOptions(0), error: nil)
		
		HTTPClient.request("PATCH", URL: URL, payload: jsonPayload) { statusCode, responseData, error in
			if let error = error {
				callback(self.handleError(statusCode, responseData: responseData, error: error))
			} else {
				callback(nil)
			}
		}
	}
}