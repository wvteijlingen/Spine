//
//  Query.swift
//  Spine
//
//  Created by Ward van Teijlingen on 30-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation
import BrightFutures


// MARK: -

public struct Query<T: ResourceProtocol> {
	
	/// The type of resource to fetch.
	var resourceType: String
	
	/// The specific IDs the fetch.
	var resourceIDs: [String]?
	
	/// The optional base URL
	internal var URL: NSURL?

	// Query parts
	internal var includes: [String] = []
	internal var filters: [NSComparisonPredicate] = []
	internal var fields: [String: [String]] = [:]
	internal var sortOrders: [String] = []
	internal var queryParts: [String: String] = [:]
	
	// Pagination parts
	internal var page: Int?
	internal var pageSize: Int?
	
	
	//MARK: Init
	
	/**
	Inits a new query for the given resource type and resource IDs
	
	:param: resourceType The type of resource to query.
	:param: resourceIDs  The IDs of the resources to query.
	
	:returns: Query
	*/
	public init(resourceType: T.Type, resourceIDs: [String]? = nil) {
		self.resourceType = resourceType.resourceType
		self.resourceIDs = resourceIDs
	}
	
	public init(resource: T) {
		assert(resource.id != nil, "Cannot instantiate query for resource, id is nil.")
		self.resourceType = resource.type
		self.resourceIDs = [resource.id!]
	}
	
	public init(linkedResourceCollection: ResourceCollection) {
		self.URL = linkedResourceCollection.href
		self.resourceType = linkedResourceCollection.type
	}
	
	public init(resourceType: T.Type, URLString: String) {
		self.resourceType = resourceType.resourceType
		self.URL = NSURL(string: URLString)
	}
	
	
	// MARK: Sideloading
	
	/**
	Includes the given relation in the query. This will fetch resources that are in that relationship.
	The relation should be specified as a dot separated path, relative to the root resource (e.g. `post.author`).
	
	:param: relation The name of the relation to include.
	
	:returns: The query.
	*/
	public mutating func include(relations: String...) -> Query {
		includes += relations
		return self
	}
	
	/**
	Removes a previously included relation.
	
	:param: relation The name of the relation not to include.
	
	:returns: The query
	*/
	public mutating func removeInclude(relations: String...) -> Query {
		includes.filter { !contains(relations, $0) }
		return self
	}
	
	
	// MARK: Where filtering
	
	private mutating func addPredicateWithKey(key: String, value: String, type: NSPredicateOperatorType) {
		let predicate = NSComparisonPredicate(
			leftExpression: NSExpression(forKeyPath: key),
			rightExpression: NSExpression(forConstantValue: value),
			modifier: NSComparisonPredicateModifier.DirectPredicateModifier,
			type: type,
			options: NSComparisonPredicateOptions.allZeros)
		
		filters.append(predicate)
	}
	
	/**
	Adds a filter where the given property should be equal to the given value.
	
	:param: property The property to filter on.
	:param: equals   The value to check for.
	
	:returns: The query
	*/
	public mutating func whereProperty(property: String, equalTo: String) -> Query {
		addPredicateWithKey(property, value: equalTo, type: .EqualToPredicateOperatorType)
		return self
	}

	/**
	Adds a filter where the given property should not be equal to the given value.
	
	:param: property The property to filter on.
	:param: equals   The value to check for.
	
	:returns: The query
	*/
	public mutating func whereProperty(property: String, notEqualTo: String) -> Query {
		addPredicateWithKey(property, value: notEqualTo, type: .NotEqualToPredicateOperatorType)
		return self
	}

	/**
	Adds a filter where the given property should be smaller than the given value.
	
	:param: property    The property to filter on.
	:param: smallerThen The value to check for.
	
	:returns: The query
	*/
	public mutating func whereProperty(property: String, lessThan: String) -> Query {
		addPredicateWithKey(property, value: lessThan, type: .LessThanPredicateOperatorType)
		return self
	}

	/**
	Adds a filter where the given property should be less then or equal to the given value.
	
	:param: property    The property to filter on.
	:param: smallerThen The value to check for.
	
	:returns: The query
	*/
	public mutating func whereProperty(property: String, lessThanOrEqualTo: String) -> Query {
		addPredicateWithKey(property, value: lessThanOrEqualTo, type: .LessThanOrEqualToPredicateOperatorType)
		return self
	}
	
	/**
	Adds a filter where the given property should be greater then the given value.
	
	:param: property    The property to filter on.
	:param: greaterThen The value to check for.
	
	:returns: The query
	*/
	public mutating func whereProperty(property: String, greaterThan: String) -> Query {
		addPredicateWithKey(property, value: greaterThan, type: .GreaterThanPredicateOperatorType)
		return self
	}

	/**
	Adds a filter where the given property should be greater than or equal to the given value.
	
	:param: property    The property to filter on.
	:param: greaterThen The value to check for.
	
	:returns: The query
	*/
	public mutating func whereProperty(property: String, greaterThanOrEqualTo: String) -> Query {
		addPredicateWithKey(property, value: greaterThanOrEqualTo, type: .GreaterThanOrEqualToPredicateOperatorType)
		return self
	}
	
	/**
	Adds a filter where the given relationship should point to the given resource, or the given
	resource should be present in the related resources.
	
	:param: relationship The name of the relationship.
	:param: resource     The resource that should be related.
	
	:returns: The query
	*/
	public mutating func whereRelationship(relationship: String, isOrContains resource: Resource) -> Query {
		assert(resource.id != nil, "Attempt to add a where filter on a relationship, but the target resource does not have an id.")
		addPredicateWithKey(relationship, value: resource.id!, type: .EqualToPredicateOperatorType)
		return self
	}
	
	
	// MARK: Sparse fieldsets
	
	/**
	Restricts the properties that should be fetched. When not set, all properties will be fetched.
	
	:param: properties Array of properties to fetch.
	
	:returns: The query
	*/
	public mutating func restrictPropertiesTo(properties: String...) -> Query {
		if var fields = fields[resourceType] {
			fields += properties
		} else {
			fields[resourceType] = properties
		}
		
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
	public mutating func restrictPropertiesOfResourceType(type: String, to properties: String...) -> Query {
		if var fields = fields[type] {
			fields += properties
		} else {
			fields[type] = properties
		}
		
		return self
	}
	
	
	// MARK: Paginating
	
	/**
	Limits the returned resources to the given page size.
	
	:param: pageSize How many resources to fetch.
	
	:returns: The query
	*/
	public mutating func limit(pageSize: Int) -> Query {
		self.pageSize = pageSize
		return self
	}
	
	/**
	The page to return on limited responses.
	
	:param: page The index of the page to fetch.
	
	:returns: The query
	*/
	public mutating func startAtPage(page: Int) -> Query {
		self.page = page
		return self
	}
	
	
	// MARK: Sorting
	
	/**
	Sort in ascending order by the the given property. Previously added properties precedence over this property.
	
	:param: property The property which to order by.
	
	:returns: The query
	*/
	public mutating func addAscendingOrder(property: String) -> Query {
		sortOrders.append(property)
		return self
	}
	
	/**
	Sort in descending order by the the given property. Previously added properties precedence over this property.
	
	:param: property The property which to order by.
	
	:returns: The query
	*/
	public mutating func addDescendingOrder(property: String) -> Query {
		sortOrders.append("-\(property)")
		return self
	}
}