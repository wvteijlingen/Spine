//
//  Resource.swift
//  Spine
//
//  Created by Ward van Teijlingen on 21-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation
import BrightFutures

let SPINE_ERROR_DOMAIN = "com.wardvanteijlingen.Spine"

public class Spine {

	public class var sharedInstance: Spine {
        struct Singleton {
            static let instance = Spine()
        }

        return Singleton.instance
    }

	/// The base URL of the API. All other URLs will be made absolute to this URL.
	public var baseURL: String
	
	/// The serializer to use for serializing and deserializing of JSON representations.
	private let serializer = Serializer()
	
	/// The HTTPClient that performs the HTTP requests.
	private let HTTPClient: HTTPClientProtocol = AlamofireClient()

	public init() {
		self.baseURL = ""
	}

	public init(endPoint: String) {
		self.baseURL = endPoint
	}
	
	public init(endPoint: String, HTTPClient: HTTPClientProtocol) {
		self.baseURL = endPoint
		self.HTTPClient = HTTPClient
	}
	
	
	// MARK: Mapping
	
	/**
	Registers the given class as a resource class.
	
	:param: type The class type.
	*/
	public func registerType(type: Resource.Type) {
		self.serializer.registerClass(type)
	}
	
	
	// MARK: Routing
	
	private func URLForCollectionOfResource(resource: Resource) -> String {
		return "\(self.baseURL)/\(resource.resourceType)"
	}
	
	private func URLForResource(resource: Resource) -> String {
		if let resourceLocation = resource.resourceLocation {
			return resourceLocation
		}
		
		assert(resource.resourceID != nil, "Resource does not have an href, nor a resource ID.")
		
		return "\(self.baseURL)/\(resource.resourceType)/\(resource.resourceID!)"
	}
	
	private func URLForQuery(query: Query) -> String {
		return query.URLRelativeToURL(self.baseURL)
	}


	// MARK: Fetching

	/**
	 Fetches a resource with the given type and ID.

	 :param: resourceType The type of resource to fetch. Must be plural.
	 :param: ID           The ID of the resource to fetch.
	 :param: success      Function to call after success.
	 :param: failure      Function to call after failure.
	 */
	public func fetchResourceWithType(resourceType: String, ID: String) -> Future<(Resource, Meta?)> {
		let promise = Promise<(Resource, Meta?)>()
		
		let query = Query(resourceType: resourceType, resourceIDs: [ID])
		
		self.fetchResourcesForQuery(query).onSuccess { resources, meta in
			promise.success(resources.first!, meta)
		}.onFailure { error in
			promise.error(error)
		}
		
		return promise.future
	}

	/**
	Fetches resources related to the given resource by a given relationship
	
	:param: relationship The name of the relationship.
	:param: resource     The resource that contains the relationship.
	
	:returns: Future of an array of resources.
	*/
	public func fetchResourcesForRelationship(relationship: String, ofResource resource: Resource) -> Future<([Resource], Meta?)> {
		let query = Query(resource: resource, relationship: relationship)
		return self.fetchResourcesForQuery(query)
	}

	/**
	Fetches resources by executing the given query.
	
	:param: query The query to execute.
	
	:returns: Future of an array of resources.
	*/
	public func fetchResourcesForQuery(query: Query) -> Future<([Resource], Meta?)> {
		let promise = Promise<([Resource], Meta?)>()
		
		let URLString = self.URLForQuery(query)
		
		println("GET: " + URLString)
		
		self.HTTPClient.get(URLString, callback: { responseStatus, responseData, error in
			if let error = error {
				println("     └─ Network error: \(error.localizedDescription)")
				promise.error(error)
				
			} else if let data = responseData {
				println("     └─ Response: \(responseStatus!)")
				
				if 200 ... 299 ~= responseStatus! {
					println("     └─ Success")
					let deserializationResult = self.serializer.deserializeData(data)
					
					if let store = deserializationResult.store {
						promise.success(store.resourcesWithName(query.resourceType), deserializationResult.meta?[query.resourceType])
					} else {
						promise.error(deserializationResult.error!)
					}
					
				} else {
					let error = self.serializer.deserializeError(data, withResonseStatus: responseStatus!)
					println("     └─ API error: \(error.localizedDescription)")
					promise.error(error)
				}
			}
		})
		
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

		let callback: (Int?, NSData?, NSError?) -> Void = { responseStatus, responseData, error in
			if let error = error {
				promise.error(error)
				return
			}
			
			// Map the response back onto the resource
			if let data = responseData {
				let store = ResourceStore(resources: [resource])
				let mappedResourcesStore = self.serializer.deserializeData(data, usingStore: store)
			}
			
			promise.success(resource)
		}
		
		// Create resource
		if resource.resourceID == nil {
			resource.resourceID = NSUUID().UUIDString
			self.HTTPClient.post(self.URLForCollectionOfResource(resource), json: self.serializer.serializeResources([resource]), callback: callback)

		// Update resource
		} else {
			self.HTTPClient.put(self.URLForResource(resource), json: self.serializer.serializeResources([resource]), callback: callback)
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
		
		let URLString = self.URLForResource(resource)
		
		self.HTTPClient.delete(URLString, callback: { responseStatus, responseData, error in
			if let error = error {
				promise.error(error)
			} else {
				promise.success()
			}
		})
		
		return promise.future
	}
}