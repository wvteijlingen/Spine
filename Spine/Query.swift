//
//  Query.swift
//  Spine
//
//  Created by Ward van Teijlingen on 30-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation

/**
A Query defines search criteria used to retrieve data from an API.
*/
public struct Query<T: ResourceProtocol> {
	
	/// The type of resource to fetch. This can be nil if in case of an expected heterogenous response.
	var resourceType: ResourceType?
	
	/// The specific IDs the fetch.
	var resourceIDs: [String]?
	
	/// The optional base URL
	internal var URL: NSURL?
	
	/// Related resources that must be included in a compound document.
	public internal(set) var includes: [String] = []
	
	/// Comparison predicates used to filter resources.
	public internal(set) var filters: [NSComparisonPredicate] = []
	
	/// Fields that will be returned, per resource type. If no fields are specified, all fields are returned.
	public internal(set) var fields: [ResourceType: [String]] = [:]
	
	/// Sort descriptors to sort resources.
	public internal(set) var sortDescriptors: [NSSortDescriptor] = []
	
	/// The page to fetch.
	var page: Int?
	
	/// The maximum number of resources per page.
	var pageSize: Int?
	
	
	//MARK: Init
	
	/**
	Inits a new query for the given resource type and optional resource IDs.
	
	:param: resourceType The type of resource to query.
	:param: resourceIDs  The IDs of the resources to query. Pass nil to fetch all resources of the given type.
	
	:returns: Query
	*/
	public init(resourceType: T.Type, resourceIDs: [String]? = nil) {
		self.resourceType = resourceType.resourceType
		self.resourceIDs = resourceIDs
	}
	
	/**
	Inits a new query that fetches the given resource.
	
	:param: resource The resource to fetch.
	
	:returns: Query
	*/
	public init(resource: T) {
		assert(resource.id != nil, "Cannot instantiate query for resource, id is nil.")
		self.URL = resource.URL
		self.resourceType = resource.dynamicType.resourceType
		self.resourceIDs = [resource.id!]
	}
	
	/**
	Inits a new query that fetches resources from the given resource collection.
	
	:param: resourceCollection The resource collection whose resources to fetch.
	
	:returns: Query
	*/
	public init(resourceCollection: ResourceCollection) {
		self.URL = resourceCollection.resourcesURL
	}
	
	/**
	Inits a new query that fetches resource of type `resourceType`, by using the given URL.
	
	:param: resourceType The type of resource to query.
	:param: URL          The URL used to fetch the resources.
	
	:returns: Query
	*/
	public init(resourceType: T.Type, path: String) {
		self.resourceType = resourceType.resourceType
		self.URL = NSURL(string: path)
	}
	
	
	// MARK: Sideloading
	
	/**
	Includes the given relation in the query. This will fetch resources that are in that relationship.
	The relation should be specified as a dot separated path, relative to the root resource (e.g. `post.author`).
	
	:param: relation The name of the relation to include.
	
	:returns: The query.
	*/
	public mutating func include(relationships: String...) -> Query {
		for relationship in relationships {
			if let relationshipName = T.fields.filter({ $0.name == relationship }).first?.name {
				includes.append(relationshipName)
			} else {
				assertionFailure("Resource of type \(T.resourceType) does not contain a relationship named \(relationship)")
			}
		}

		return self
	}
	
	/**
	Removes a previously included relation.
	
	:param: relation The name of the included relationship to remove.
	
	:returns: The query
	*/
	public mutating func removeInclude(relationships: String...) -> Query {
		for relationship in relationships {
			if let relationshipName = T.fields.filter({ $0.name == relationship }).first?.name {
				if let index = find(includes, relationshipName) {
					includes.removeAtIndex(index)
				} else {
					assertionFailure("Attempt to remove include that was not included: \(relationshipName)")
				}
			} else {
				assertionFailure("Resource of type \(T.resourceType) does not contain a relationship named \(relationship)")
			}
		}

		return self
	}
	
	
	// MARK: Predicate filtering
	
	private mutating func addPredicateWithKey(key: String, value: String, type: NSPredicateOperatorType) {
		let predicate = NSComparisonPredicate(
			leftExpression: NSExpression(forKeyPath: key),
			rightExpression: NSExpression(forConstantValue: value),
			modifier: .DirectPredicateModifier,
			type: type,
			options: .allZeros)
		
		addPredicate(predicate)
	}
	
	/**
	Adds the given predicate as a filter.
	
	:param: predicate The predicate to add.
	*/
	public mutating func addPredicate(predicate: NSComparisonPredicate) {
		filters.append(predicate)
	}
	
	
	// MARK: Convenience filtering
	
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
		assert(resourceType != nil, "Cannot restrict properties for query without resource type, use `restrictPropertiesOfResourceType` or set a resource type.")
		
		if var fields = fields[resourceType!] {
			fields += properties
		} else {
			fields[resourceType!] = properties
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
		sortDescriptors.append(NSSortDescriptor(key: property, ascending: true))
		return self
	}
	
	/**
	Sort in descending order by the the given property. Previously added properties precedence over this property.
	
	:param: property The property which to order by.
	
	:returns: The query
	*/
	public mutating func addDescendingOrder(property: String) -> Query {
		sortDescriptors.append(NSSortDescriptor(key: property, ascending: false))
		return self
	}
}