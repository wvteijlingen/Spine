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
import BrightFutures

let SPINE_ERROR_DOMAIN = "com.wardvanteijlingen.Spine"

public class Spine {

	public class var sharedInstance: Spine {
        struct Singleton {
            static let instance = Spine()
        }

        return Singleton.instance
    }

	public var endPoint: String
	private var serializer: Serializer = Serializer()

	public init() {
		self.endPoint = ""
	}

	public init(endPoint: String) {
		self.endPoint = endPoint
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
		return "\(self.endPoint)/\(resource.resourceType)"
	}
	
	private func URLForResource(resource: Resource) -> String {
		if let resourceLocation = resource.resourceLocation {
			return resourceLocation
		}
		
		return "\(self.endPoint)/\(resource.resourceType)/\(resource.resourceID!)"
	}
	
	private func URLForQuery(query: Query) -> String {
		return query.URLRelativeToURL(self.endPoint)
	}


	// MARK: Fetching

	/**
	 Fetches a resource with the given type and ID.

	 :param: resourceType The type of resource to fetch. Must be plural.
	 :param: ID           The ID of the resource to fetch.
	 :param: success      Function to call after success.
	 :param: failure      Function to call after failure.
	 */
	public func fetchResourceWithType(resourceType: String, ID: String) -> Future<Resource> {
		let promise = Promise<Resource>()
		
		let query = Query(resourceType: resourceType, resourceIDs: [ID])
		
		self.fetchResourcesForQuery(query).onSuccess { resources in
			promise.success(resources.first!)
		}.onFailure { error in
			promise.error(error)
		}
		
		return promise.future
	}

	/**
	 Fetches resources related to the given resource by a given relationship.

	 :param: relation The name of the relationship.
	 :param: resource The resource that contains the relationship.
	 :param: success  Function to call after success.
	 :param: failure  Function to call after failure.
	 */
	public func fetchResourcesForRelationship(relationship: String, ofResource resource: Resource) -> Future<[Resource]> {
		let query = Query(resource: resource, relationship: relationship)
		return self.fetchResourcesForQuery(query)
	}

	/**
	 Fetches resources by executing the given query.

	 :param: query   The query to execute.
	 :param: success Function to call after success.
	 :param: failure Function to call after failure.
	 */
	public func fetchResourcesForQuery(query: Query) -> Future<[Resource]> {
		let promise = Promise<[Resource]>()
		
		let URLString = self.URLForQuery(query)
		Alamofire.request(.GET, URLString).response { (request: NSURLRequest, response: NSHTTPURLResponse?, data: AnyObject?, error: NSError?) -> Void in
			if let error = error {
				promise.error(error)
				return
			}

			if let JSONData: NSData = data as? NSData {
				let JSON = JSONValue(JSONData as NSData!)
				
				if response!.statusCode >= 200 && response!.statusCode < 300 {

					let mappedResourcesStore = self.serializer.unserializeData(JSON)
					if let fetchedResources = mappedResourcesStore.resourcesWithName(query.resourceType) {
						promise.success(fetchedResources)
					} else {
						promise.error(NSError())
					}

				} else {
					let code = JSON["errors"][0]["id"].integer ?? response!.statusCode
					var userInfo: [String : AnyObject]?
					if JSON["errors"][0]["title"].string != nil {
						userInfo = [NSLocalizedDescriptionKey: JSON["errors"][0]["title"].string!]
					}
					promise.error(NSError(domain: SPINE_ERROR_DOMAIN, code: code, userInfo: userInfo))
				}
			}
		}
		
		return promise.future
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
	public func saveResource(resource: Resource) -> Future<Resource> {
		let promise = Promise<Resource>()
		
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

		let parameters = self.serializer.serializeResources([resource])

		let request = Alamofire.request(method, URL, parameters: parameters, encoding: Alamofire.ParameterEncoding.JSON)
		request.response { (request: NSURLRequest, response: NSHTTPURLResponse?, data: AnyObject?, error: NSError?) -> Void in
			var lastError: NSError? = nil

			if let error = error {
				lastError = error
				promise.error(error)
				return
			}

			// Map the response back onto the resource
			if let JSONData: NSData = data as? NSData {
				let JSON = JSONValue(JSONData as NSData!)
				let store = ResourceStore(resources: [resource])
				let mappedResourcesStore = self.serializer.unserializeData(JSON, usingStore: store)
			}

			promise.success(resource)
		}
		
		return promise.future
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
	public func deleteResource(resource: Resource, success: () -> Void, failure: (NSError) -> Void) -> Future<Void> {
		let promise = Promise<Void>()
		
		let URLString = self.URLForResource(resource)
		Alamofire.request(Alamofire.Method.DELETE, URLString).response { (request: NSURLRequest, response: NSHTTPURLResponse?, data: AnyObject?, error: NSError?) -> Void in
			if let error = error {
				promise.error(error)
			} else {
				promise.success()
			}
		}
		
		return promise.future
	}
}