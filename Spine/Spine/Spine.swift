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

	var endPoint: String
	var mapper: Mapper = Mapper()

	public init(endPoint: String) {
		self.endPoint = endPoint
	}

	public func fetchResource(resourceType: String, ID: String, success: (Resource) -> Void, failure: (NSError) -> Void) {
		let query = Query(resourceType: resourceType, resourceIDs: [ID])
		self.fetchResourcesForQuery(query, success: { (resources: [Resource]) in
			success(resources.first!)
		}, failure)
	}

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

	public func fetchResourcesForRelation(relation: String, ofResource resource: Resource, success: ([Resource]) -> Void, failure: (NSError) -> Void) {
		if let relationship = resource.relationships[relation] {
			let query = Query(resource: resource, relation: relationship)
			self.fetchResourcesForQuery(query, success, failure)
		} else {
			failure(NSError())
		}
	}

	/**
	 Saves a resource to the server.
	 This will also relate and unrelate any pending related and unrelated resource.
	 Related resources will not be saved automatically. You must ensure that related resources are saved before saving any parent resource.

	 :param: resource The resource to save
	 :param: success  Function to call after successful saving
	 :param: failure  Function to call after saving failed
	 */
	public func saveResource(resource: Resource, success: () -> Void, failure: (NSError) -> Void) {
		if resource.resourceID == nil {
			resource.resourceID = NSUUID().UUIDString
		}

		// PUT the main resource
		let parameters = self.mapper.mapResourcesToDictionary([resource])
		let URLString = self.URLForResource(resource)

		let request = Alamofire.request(Alamofire.Method.PUT, URLString, parameters: parameters, encoding: Alamofire.ParameterEncoding.JSON)
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
				let store = ResourceStore()
				store.add(resource)
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

	/**
	 Deletes the resource from the server.
     This will fire a DELETE request to an URL of the form: /{resourceType}/{id}

	 :param: resource The resource to delete
	 :param: success  Function to call after successful deleting
	 :param: failure  Function to call after deleting failed
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
	func URLForResource(resource: Resource) -> String {
		if let resourceLocation = resource.resourceLocation {
			return resourceLocation
		}

		let resourceType = resource.resourceType
		return "\(self.endPoint)/\(resourceType)/\(resource.resourceID!)"
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

// MARK: - Query

public class Query {

	private struct QueryFilter {
		var key: String
		var value: String
		var comparator: String

		var rhs: String {
			get {
				if self.comparator == "=" {
					return self.value
				} else {
					return self.comparator + self.value
				}
			}
		}

		init(property: String, value: String, comparator: String) {
			self.key = property
			self.value = value
			self.comparator = comparator
		}
	}

	var URL: NSURL
	var resourceType: String

	private var includes: [String] = []
	private var filters: [QueryFilter] = []
	private var fields: [String: [String]] = [:]

	/**
	 Inits a new query for the given resource type.

	 :param: resourceType The type of resource to query.

	 :returns: Query
	 */
	public init(resourceType: String) {
		self.URL = NSURL(string: resourceType)
		self.resourceType = resourceType
	}

	/**
	 Inits a new query for the given resource type and resource IDs

	 :param: resourceType The type of resource to query.
	 :param: resourceIDs  The IDs of the resources to query.

	 :returns: Query
	 */
	public init(resourceType: String, resourceIDs: [String]) {
		self.URL = NSURL(string: resourceType).URLByAppendingPathComponent((resourceIDs as NSArray).componentsJoinedByString(","))
		self.resourceType = resourceType
	}

	public init(resource: Resource, relation: ResourceRelation) {
		switch relation {
			case .ToOne(let href, let ID, let type):
				self.resourceType = type
				self.URL = NSURL(string: href)
			case .ToMany(let href, let IDs, let type):
				self.resourceType = type
				self.URL = NSURL(string: href)
		}
	}

	/**
	 Includes the given relation in the query. This will fetch resources that are in that relationship.
	 The relation should be specified as a dot separated path, relative to the root resource (e.g. `post.author`).

	 :param: relation The name of the relation to include.

	 :returns: The query.
	 */
	public func include(relation: String)  -> Self {
		self.includes.append(relation)
		return self
	}

	/**
	 Includes the given relations in the query.
	 See include(relation: String) for more information.

	 :param: relations The name of the relation to include.

	 :returns: The query
	 */
	public func include(relations: [String]) -> Self {
		self.includes += relations
		return self
	}

	/**
	 Removes a previously included relation.

	 :param: relation The name of the relation not to include.

	 :returns: The query
	 */
	public func removeInclude(relation: String) -> Self {
		self.includes.filter({$0 != relation})
		return self
	}

	/**
	 Adds a filter where the given property should be equal to the given value.

	 :param: property The property to filter on.
	 :param: equals   The value to check for.

	 :returns: The query
	 */
	public func whereProperty(property: String, equals: String) -> Self {
		self.filters.append(QueryFilter(property: property, value: equals, comparator: "="))
		return self
	}

	/**
	 Adds a filter where the given relationship should point to the given resource, or the given
	 resource should be present in the related resources.

	 :param: relationship The name of the relationship.
	 :param: resource     The resource that should be related.

	 :returns: The query
	 */
	public func whereRelationship(relationship: String, isOrContains resource: Resource) -> Self {
		if let resourceID = resource.resourceID {
			self.filters.append(QueryFilter(property: relationship, value: resourceID, comparator: "="))
		} else {
			println("Warning: Attempt to add a where filter on a relationship, but the target resource does not contain a resource ID.")
		}
		return self
	}

	/**
	 Adds a filter where the given property should be smaller then the given value.

	 :param: property    The property to filter on.
	 :param: smallerThen The value to check for.

	 :returns: The query
	 */
	public func whereProperty(property: String, smallerThen: String) -> Self {
		self.filters.append(QueryFilter(property: property, value: smallerThen, comparator: "<"))
		return self
	}

	/**
	 Adds a filter where the given property should be greater then the given value.

	 :param: property    The property to filter on.
	 :param: greaterThen The value to check for.

	 :returns: The query
	 */
	public func whereProperty(property: String, greaterThen: String) -> Self {
		self.filters.append(QueryFilter(property: property, value: greaterThen, comparator: ">"))
		return self
	}

	public func restrictProperties(properties: [String]) -> Self {
		self.restrictProperties(properties, ofResourceType: self.resourceType)
		return self
	}

	public func restrictProperties(properties: [String], ofResourceType type: String) -> Self {
		if var fields = self.fields[type] {
			fields += properties
		} else {
			self.fields[type] = properties
		}

		return self
	}

	/**
	 Returns the URL string of this query, relative to the given base URL.

	 :param: baseURL The base URL string of the API.

	 :returns: The URL string for this query.
	 */
	public func URLRelativeToURL(baseURL: String) -> String {
		var URL = NSURL(string: self.URL.absoluteString!, relativeToURL: NSURL(string: baseURL))
		var queryItems: [AnyObject] = []

		// Includes
		if self.includes.count != 0 {
			var item = NSURLQueryItem(name: "include", value: (self.includes as NSArray).componentsJoinedByString(","))
			queryItems.append(item)
		}

		// Filters
		for filter in self.filters {
			var item = NSURLQueryItem(name: filter.key, value: filter.rhs)
			queryItems.append(item)
		}

		// Fields
		for (resourceType, fields) in self.fields {
			var item = NSURLQueryItem(name: "fields[\(resourceType)]", value: (fields as NSArray).componentsJoinedByString(","))
			queryItems.append(item)
		}

		let URLComponents = NSURLComponents(URL: URL, resolvingAgainstBaseURL: true)
		if queryItems.count != 0 {
			URLComponents.queryItems = queryItems
		}
		return URLComponents.string
	}
}