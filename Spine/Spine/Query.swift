//
//  Query.swift
//  Spine
//
//  Created by Ward van Teijlingen on 30-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation

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
	
	public init(resource: Resource, relationship: ResourceRelationship) {
		switch relationship {
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