//
//  Query.swift
//  Spine
//
//  Created by Ward van Teijlingen on 30-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation
import BrightFutures

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

// MARK: -

public class Query {
	
	// Base parts
	var resourceType: String
	private var URL: NSURL

	// Query parts
	private var includes: [String] = []
	private var filters: [QueryFilter] = []
	private var fields: [String: [String]] = [:]
	private var sortOrders: [String] = []
	
	// Pagination parts. These are scoped internal so they can be accessed by the Paginator class.
	internal var page: Int?
	internal var pageSize: Int?
	
	
	//MARK: Init
	
	/**
	Inits a new query for the given resource type.
	
	:param: resourceType The type of resource to query.
	
	:returns: Query
	*/
	public init(resourceType: String) {
		self.URL = NSURL(string: resourceType)!
		self.resourceType = resourceType
	}
	
	/**
	Inits a new query for the given resource type and resource IDs
	
	:param: resourceType The type of resource to query.
	:param: resourceIDs  The IDs of the resources to query.
	
	:returns: Query
	*/
	public init(resourceType: String, resourceIDs: [String]) {
		self.URL = NSURL(string: resourceType)!.URLByAppendingPathComponent(",".join(resourceIDs))
		self.resourceType = resourceType
	}
	
	/**
	Inits a new query to fetch related resources related by a relationship.
	
	:param: resource     The resource that links to the related resources.
	:param: relationship The name of the relationship.
	
	:returns: Query
	*/
	public init(resource: Resource, relationship: String) {
		assert(resource.links[relationship] != nil, "Specified relationship does not exist")
		
		let link = resource.links[relationship]
		
		self.resourceType = link!.type ?? relationship

		if let href = link!.href {
			self.URL = NSURL(string: href)!
		} else {
			self.URL = NSURL(string: self.resourceType)!.URLByAppendingPathComponent(link!.joinedIDs)
		}
	}
	
	
	// MARK: Sideloading
	
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
	
	
	// MARK: Where filtering
	
	/**
	Adds a filter where the given property should be equal to the given value.
	
	:param: property The property to filter on.
	:param: equals   The value to check for.
	
	:returns: The query
	*/
	public func whereProperty(property: String, equalTo: String) -> Self {
		self.filters.append(QueryFilter(property: property, value: equalTo, comparator: "="))
		return self
	}

	/**
	Adds a filter where the given property should not be equal to the given value.
	
	:param: property The property to filter on.
	:param: equals   The value to check for.
	
	:returns: The query
	*/
	public func whereProperty(property: String, notEqualTo: String) -> Self {
		self.filters.append(QueryFilter(property: property, value: notEqualTo, comparator: "=!"))
		return self
	}

	/**
	Adds a filter where the given property should be smaller than the given value.
	
	:param: property    The property to filter on.
	:param: smallerThen The value to check for.
	
	:returns: The query
	*/
	public func whereProperty(property: String, lessThan: String) -> Self {
		self.filters.append(QueryFilter(property: property, value: lessThan, comparator: "<"))
		return self
	}

	/**
	Adds a filter where the given property should be less then or equal to the given value.
	
	:param: property    The property to filter on.
	:param: smallerThen The value to check for.
	
	:returns: The query
	*/
	public func whereProperty(property: String, lessThanOrEqualTo: String) -> Self {
		self.filters.append(QueryFilter(property: property, value: lessThanOrEqualTo, comparator: "<="))
		return self
	}
	
	/**
	Adds a filter where the given property should be greater then the given value.
	
	:param: property    The property to filter on.
	:param: greaterThen The value to check for.
	
	:returns: The query
	*/
	public func whereProperty(property: String, greaterThan: String) -> Self {
		self.filters.append(QueryFilter(property: property, value: greaterThan, comparator: ">"))
		return self
	}

	/**
	Adds a filter where the given property should be greater than or equal to the given value.
	
	:param: property    The property to filter on.
	:param: greaterThen The value to check for.
	
	:returns: The query
	*/
	public func whereProperty(property: String, greaterThanOrEqualTo: String) -> Self {
		self.filters.append(QueryFilter(property: property, value: greaterThanOrEqualTo, comparator: ">="))
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
		assert(resource.resourceID != nil, "Attempt to add a where filter on a relationship, but the target resource does not contain a resource ID.")
		self.filters.append(QueryFilter(property: relationship, value: resource.resourceID!, comparator: "="))
		return self
	}
	
	
	// MARK: Sparse fieldsets
	
	/**
	Restricts the properties that should be fetched. When not set, all properties will be fetched.
	
	:param: properties Array of properties to fetch.
	
	:returns: The query
	*/
	public func restrictProperties(properties: [String]) -> Self {
		self.restrictProperties(properties, ofResourceType: self.resourceType)
		return self
	}
	
	/**
	Restricts the properties of a specific resource type that should be fetched.
	This method can be used to restrict properties of included resources. When not set,
	all properties will be fetched.
	
	
	:param: properties Array of properties to fetch.
	:param: type       The resource type for which to restrict the properties.
	
	:returns: The query
	*/
	public func restrictProperties(properties: [String], ofResourceType type: String) -> Self {
		if var fields = self.fields[type] {
			fields += properties
		} else {
			self.fields[type] = properties
		}
		
		return self
	}
	
	
	// MARK: Paginating
	
	/**
	Limits the returned resources to the given page size.
	
	:param: pageSize How many resources to fetch.
	
	:returns: The query
	*/
	public func limit(pageSize: Int) -> Self {
		self.pageSize = pageSize
		return self
	}
	
	/**
	The page to return on limited responses.
	
	:param: page The index of the page to fetch.
	
	:returns: The query
	*/
	public func startAtPage(page: Int) -> Self {
		self.page = page
		return self
	}
	
	
	// MARK: Sorting
	
	/**
	Sort in ascending order by the the given property. Previously added properties precedence over this property.
	
	:param: property The property which to order by.
	
	:returns: The query
	*/
	public func addAscendingOrder(property: String) -> Self {
		self.sortOrders.append(property)
		return self
	}
	
	/**
	Sort in descending order by the the given property. Previously added properties precedence over this property.
	
	:param: property The property which to order by.
	
	:returns: The query
	*/
	public func addDescendingOrder(property: String) -> Self {
		self.sortOrders.append("-\(property)")
		return self
	}
	
	
	// MARK: URL building
	
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
			var item = NSURLQueryItem(name: "include", value: ",".join(self.includes))
			queryItems.append(item)
		}
		
		// Filters
		for filter in self.filters {
			var item = NSURLQueryItem(name: filter.key, value: filter.rhs)
			queryItems.append(item)
		}
		
		// Fields
		for (resourceType, fields) in self.fields {
			var item = NSURLQueryItem(name: "fields[\(resourceType)]", value: ",".join(fields))
			queryItems.append(item)
		}
		
		// Sorting
		if self.sortOrders.count != 0 {
			var item = NSURLQueryItem(name: "sort", value: ",".join(self.sortOrders))
			queryItems.append(item)
		}
		
		// Pagination
		if let page = self.page {
			var item = NSURLQueryItem(name: "page", value: String(page))
			queryItems.append(item)
		}
		
		if let pageSize = self.pageSize {
			var item = NSURLQueryItem(name: "page_size", value: String(pageSize))
			queryItems.append(item)
		}
		
		let URLComponents = NSURLComponents(URL: URL!, resolvingAgainstBaseURL: true)!
		
		if URLComponents.queryItems != nil {
			URLComponents.queryItems! += queryItems
		} else {
			URLComponents.queryItems = queryItems
		}
		
		return URLComponents.string! //TODO: Check forced unwrapping
	}
}

// MARK: - Convenience functions
extension Query {
	public func findResources() -> Future<([Resource], Meta?)> {
		return Spine.sharedInstance.fetchResourcesForQuery(self)
	}
}