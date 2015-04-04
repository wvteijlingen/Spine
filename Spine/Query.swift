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
	public mutating func include(relationshipNames: String...) -> Query {
		for relationshipName in relationshipNames {
			if let relationship = T.fields.filter({ $0.name == relationshipName }).first {
				includes.append(relationship.serializedName)
			} else {
				assertionFailure("Resource of type \(T.resourceType) does not contain a relationship named \(relationshipName)")
			}
		}

		return self
	}
	
	/**
	Removes a previously included relation.
	
	:param: relation The name of the included relationship to remove.
	
	:returns: The query
	*/
	public mutating func removeInclude(relationshipNames: String...) -> Query {
		for relationshipName in relationshipNames {
			if let relationship = T.fields.filter({ $0.name == relationshipName }).first {
				if let index = find(includes, relationship.serializedName) {
					includes.removeAtIndex(index)
				} else {
					assertionFailure("Attempt to remove include that was not included: \(relationshipName)")
				}
			} else {
				assertionFailure("Resource of type \(T.resourceType) does not contain a relationship named \(relationshipName)")
			}
		}

		return self
	}
	
	
	// MARK: Filtering
	
	private mutating func addPredicateWithField(fieldName: String, value: AnyObject, type: NSPredicateOperatorType) {
		if let field = T.fields.filter({ $0.name == fieldName }).first {
			let predicate = NSComparisonPredicate(
				leftExpression: NSExpression(forKeyPath: field.serializedName),
				rightExpression: NSExpression(forConstantValue: value),
				modifier: .DirectPredicateModifier,
				type: type,
				options: .allZeros)
			
			addPredicate(predicate)
		} else {
			assertionFailure("Resource of type \(T.resourceType) does not contain a field named \(fieldName)")
		}
	}
	
	/**
	Adds the given predicate as a filter.
	
	:param: predicate The predicate to add.
	*/
	public mutating func addPredicate(predicate: NSComparisonPredicate) {
		filters.append(predicate)
	}
	
	/**
	Adds a filter where the given attribute should be equal to the given value.
	
	:param: attributeName The name of the attribute to filter on.
	:param: equals        The value to check for.
	
	:returns: The query
	*/
	public mutating func whereAttribute(attributeName: String, equalTo: AnyObject) -> Query {
		addPredicateWithField(attributeName, value: equalTo, type: .EqualToPredicateOperatorType)
		return self
	}

	/**
	Adds a filter where the given attribute should not be equal to the given value.
	
	:param: attributeName The name of the attribute to filter on.
	:param: equals        The value to check for.
	
	:returns: The query
	*/
	public mutating func whereAttribute(attributeName: String, notEqualTo: AnyObject) -> Query {
		addPredicateWithField(attributeName, value: notEqualTo, type: .NotEqualToPredicateOperatorType)
		return self
	}

	/**
	Adds a filter where the given attribute should be smaller than the given value.
	
	:param: attributeName The name of the attribute to filter on.
	:param: smallerThen   The value to check for.
	
	:returns: The query
	*/
	public mutating func whereAttribute(attributeName: String, lessThan: AnyObject) -> Query {
		addPredicateWithField(attributeName, value: lessThan, type: .LessThanPredicateOperatorType)
		return self
	}

	/**
	Adds a filter where the given attribute should be less then or equal to the given value.
	
	:param: attributeName The name of the attribute to filter on.
	:param: smallerThen   The value to check for.
	
	:returns: The query
	*/
	public mutating func whereAttribute(attributeName: String, lessThanOrEqualTo: AnyObject) -> Query {
		addPredicateWithField(attributeName, value: lessThanOrEqualTo, type: .LessThanOrEqualToPredicateOperatorType)
		return self
	}
	
	/**
	Adds a filter where the given attribute should be greater then the given value.
	
	:param: attributeName The name of the attribute to filter on.
	:param: greaterThen   The value to check for.
	
	:returns: The query
	*/
	public mutating func whereAttribute(attributeName: String, greaterThan: AnyObject) -> Query {
		addPredicateWithField(attributeName, value: greaterThan, type: .GreaterThanPredicateOperatorType)
		return self
	}

	/**
	Adds a filter where the given attribute should be greater than or equal to the given value.
	
	:param: attributeName The name of the attribute to filter on.
	:param: greaterThen   The value to check for.
	
	:returns: The query
	*/
	public mutating func whereAttribute(attributeName: String, greaterThanOrEqualTo: AnyObject) -> Query {
		addPredicateWithField(attributeName, value: greaterThanOrEqualTo, type: .GreaterThanOrEqualToPredicateOperatorType)
		return self
	}
	
	/**
	Adds a filter where the given relationship should point to the given resource, or the given
	resource should be present in the related resources.
	
	:param: relationshipName The name of the relationship to filter on.
	:param: resource         The resource that should be related.
	
	:returns: The query
	*/
	public mutating func whereRelationship(relationshipName: String, isOrContains resource: ResourceProtocol) -> Query {
		assert(resource.id != nil, "Attempt to add a where filter on a relationship, but the target resource does not have an id.")
		addPredicateWithField(relationshipName, value: resource.id!, type: .EqualToPredicateOperatorType)
		return self
	}
	
	
	// MARK: Sparse fieldsets
	
	/**
	Restricts the fields that should be requested. When not set, all fields will be requested.
	Note: the server may still choose to return only of a select set of fields.
	
	:param: fieldNames Names of fields to fetch.
	
	:returns: The query
	*/
	public mutating func restrictFieldsTo(fieldNames: String...) -> Query {
		assert(resourceType != nil, "Cannot restrict fields for query without resource type, use `restrictFieldsOfResourceType` or set a resource type.")
		
		if var fields = fields[resourceType!] {
			fields += fieldNames
		} else {
			fields[resourceType!] = fieldNames
		}
		
		return self
	}
	
	/**
	Restricts the fields of a specific resource type that should be requested.
	This method can be used to restrict fields of included resources. When not set, all fields will be requested.
	
	Note: the server may still choose to return only of a select set of fields.
	
	:param: type       The resource type for which to restrict the properties.
	:param: fieldNames Names of fields to fetch.
	
	:returns: The query
	*/
	public mutating func restrictFieldsOfResourceType(type: String, to fieldNames: String...) -> Query {
		if var fields = fields[type] {
			fields += fieldNames
		} else {
			fields[type] = fieldNames
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