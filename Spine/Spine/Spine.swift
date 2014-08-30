//
//  Resource.swift
//  Spine
//
//  Created by Ward van Teijlingen on 21-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON

public class Spine {

	public var endPoint: String
	private var mapper: Mapper = Mapper()

	public init(endPoint: String) {
		self.endPoint = endPoint
	}

	// MARK: Fetching

	/**
	 Fetches a resource with the given type and ID.

	 :param: resourceType The type of resource to fetch. Must be plural.
	 :param: ID           The ID of the resource to fetch.
	 :param: success      Function to call after success.
	 :param: failure      Function to call after failure.
	 */
	public func fetchResourceWithType(resourceType: String, ID: String, success: (Resource) -> Void, failure: (NSError) -> Void) {
		let query = Query(resourceType: resourceType, resourceIDs: [ID])
		self.fetchResourcesForQuery(query, success: { (resources: [Resource]) in
			success(resources.first!)
		}, failure)
	}

	/**
	 Fetches resources by executing the given query.

	 :param: query   The query to execute.
	 :param: success Function to call after success.
	 :param: failure Function to call after failure.
	 */
	public func fetchResourcesForQuery(query: Query, success: ([Resource]) -> Void, failure: (NSError) -> Void) {
		let URLString = self.URLForQuery(query)
		Alamofire.request(.GET, URLString).response { (request: NSURLRequest, response: NSHTTPURLResponse?, data: AnyObject?, error: NSError?) -> Void in
			if let error = error {
				println("Error: \(error)")
				return
			}

			if let JSONData: NSData = data as? NSData {
				let JSON = JSONValue(JSONData as NSData!)
				let mappedResourcesStore = self.mapper.mapResponseData(JSON)
				if let fetchedResources = mappedResourcesStore.resourcesWithName(query.resourceType) {
					success(fetchedResources)
				} else {
					failure(NSError())
				}
			}
		}
	}

	/**
	 Fetches resources related to the given resource by a given relationship.

	 :param: relation The name of the relationship.
	 :param: resource The resource that contains the relationship.
	 :param: success  Function to call after success.
	 :param: failure  Function to call after failure.
	 */
	public func fetchResourcesForRelationship(relationship: String, ofResource resource: Resource, success: ([Resource]) -> Void, failure: (NSError) -> Void) {
		if let relationship = resource.relationships[relationship] {
			let query = Query(resource: resource, relationship: relationship)
			self.fetchResourcesForQuery(query, success, failure)
		} else {
			failure(NSError())
		}
	}

	
	// MARK: Saving

	/**
	 Saves a resource to the server.
	 This will also relate and unrelate any pending related and unrelated resource.
	 Related resources will not be saved automatically. You must ensure that related resources are saved before saving any parent resource.

	 :param: resource The resource to save.
	 :param: success  Function to call after successful saving.
	 :param: failure  Function to call after saving failed.
	 */
	public func saveResource(resource: Resource, success: () -> Void, failure: (NSError) -> Void) {
		var method: Alamofire.Method
		var URL: String

		// POST
		if resource.resourceID == nil {
			resource.resourceID = NSUUID().UUIDString
			method = Alamofire.Method.POST
			URL = self.URLForCollectionOfResource(resource)

		// PUT
		} else {
			method = Alamofire.Method.PUT
			URL = self.URLForResource(resource)
		}

		let parameters = self.mapper.mapResourcesToDictionary([resource])

		let request = Alamofire.request(method, URL, parameters: parameters, encoding: Alamofire.ParameterEncoding.JSON)
		request.response { (request: NSURLRequest, response: NSHTTPURLResponse?, data: AnyObject?, error: NSError?) -> Void in
			var lastError: NSError? = nil

			if let error = error {
				lastError = error
				failure(error)
				return
			}

			// Map the response back onto the resource
			if let JSONData: NSData = data as? NSData {
				let JSON = JSONValue(JSONData as NSData!)
				let store = ResourceStore(resources: [resource])
				let mappedResourcesStore = self.mapper.mapResponseData(JSON, usingStore: store)
			}

			success()
		}
	}


	/**
	 Performs a request to relate the given resources to a resource for a certain relationship.
	 This will fire a POST request to an URL of the form: /{resourceType}/{id}/links/{relationship}/{ids}

	 :param: resources         The resources to relate
	 :param: toResource        The resource to relate to
	 :param: relationship      The name of the relationship to relate the resources for
	 :param: completionHandler Function to call after completion
	 */
	func relateResources(resources: [Resource], toResource: Resource, relationship: String, completionHandler: (NSError?) -> Void) {
		let IDs: [String] = resources.map { (resource) in
			assert(resource.resourceID != nil, "Attempt to relate resource without ID. Only existing resources can be related.")
			return resource.resourceID!
		}

		let requestURL = self.URLForResource(toResource) + "/links/" + relationship

		Alamofire.request(Alamofire.Method.POST, requestURL, parameters: [relationship: IDs], encoding: Alamofire.ParameterEncoding.JSON)
			.response { (request: NSURLRequest, response: NSHTTPURLResponse?, data: AnyObject?, error: NSError?) -> Void in
			if let error = error {
				println("Error processing pending related resources: \(error)")
				return
			}

			println("Pending related resources processed")
		}
	}

	/**
	 Performs a request to unrelate the given resources to a resource for a certain relationship.
	 This will fire a DELETE request to an URL of the form: /{resourceType}/{id}/links/{relationship}/{ids}

	 :param: resources         The resources to remove from the relation
	 :param: fromResource      The resource from which to remove the related resources
	 :param: relationship      The name of the relationship from which to unrelate the resources
	 :param: completionHandler Function to call after completion
	 */
	func unrelateResources(resources: [Resource], fromResource: Resource, relationship: String, completionHandler: (NSError?) -> Void) {
		let IDs: [String] = resources.map { (resource) in
			assert(resource.resourceID != nil, "Attempt to unrelate resource without ID. Only existing resources can be unrelated.")
			return resource.resourceID!
		}

		let requestURL = self.URLForResource(fromResource) + "/links/" + relationship + "/" + (IDs as NSArray).componentsJoinedByString(",")

		Alamofire.request(Alamofire.Method.DELETE, requestURL).response { (request: NSURLRequest, response: NSHTTPURLResponse?, data: AnyObject?, error: NSError?) -> Void in
			if let error = error {
				println("Error processing pending unrelated resources: \(error)")
				return
			}

			println("Pending unrelated resources processed")
		}
	}


	// MARK: Deleting

	/**
	 Deletes the resource from the server.
     This will fire a DELETE request to an URL of the form: /{resourceType}/{id}

	 :param: resource The resource to delete.
	 :param: success  Function to call after successful deleting.
	 :param: failure  Function to call after deleting failed.
	 */
	public func deleteResource(resource: Resource, success: () -> Void, failure: (NSError) -> Void) {
		let URLString = self.URLForResource(resource)
		Alamofire.request(Alamofire.Method.DELETE, URLString).response { (request: NSURLRequest, response: NSHTTPURLResponse?, data: AnyObject?, error: NSError?) -> Void in
			if let error = error {
				failure(error)
			} else {
				success()
			}
		}
	}
}


// MARK: - Routing
extension Spine {
	func URLForCollectionOfResource(resource: Resource) -> String {
		return "\(self.endPoint)/\(resource.resourceType)"
	}

	func URLForResource(resource: Resource) -> String {
		if let resourceLocation = resource.resourceLocation {
			return resourceLocation
		}

		return "\(self.endPoint)/\(resource.resourceType)/\(resource.resourceID!)"
	}

	func URLForQuery(query: Query) -> String {
		return query.URLRelativeToURL(self.endPoint)
	}
}


// MARK: - Mapping
extension Spine {
	public func registerType(type: Resource.Type, resourceType: String) {
		self.mapper.registerType(type, resourceType: resourceType)
	}
	
	public func classNameForResourceType(resourceType: String) -> Resource.Type {
		return self.mapper.classNameForResourceType(resourceType)
	}
}