//
//  Routing.swift
//  Spine
//
//  Created by Ward van Teijlingen on 24-09-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation

/**
The RouterProtocol declares methods and properties that a router should implement.
The router is used to build URLs for API requests.
*/
public protocol Router: class {
	/// The base URL of the API.
	var baseURL: URL! { get set }
	var keyFormatter: KeyFormatter! { get set }
	
	/**
	Returns an URL that points to the collection of resources with a given type.
	
	- parameter type: The type of resources.
	
	- returns: The URL.
	*/
	func urlForResourceType(_ type: ResourceType) -> URL
	
	/**
	Returns an URL that points to a relationship of a resource.
	
	- parameter relationship: The relationship to get the URL for.
	- parameter resource:     The resource that contains the relationship.
	
	- returns: The URL.
	*/
	func urlForRelationship<T: Resource>(_ relationship: Relationship, ofResource resource: T) -> URL
	
	/**
	Returns an URL that represents the given query.
	
	- parameter query: The query to turn into an URL.
	
	- returns: The URL.
	*/
	func urlForQuery<T: Resource>(_ query: Query<T>) -> URL
}

/**
The built in JSONAPIRouter builds URLs according to the JSON:API specification.

Filters
=======
Only 'equal to' filters are supported. You can subclass Router and override
`queryItemForFilter` to add support for other filtering strategies.

Pagination
==========
Only PageBasedPagination and OffsetBasedPagination are supported. You can subclass Router
and override `queryItemsForPagination` to add support for other pagination strategies.
*/
open class JSONAPIRouter: Router {
	open var baseURL: URL!
	open var keyFormatter: KeyFormatter!

	public init() { }
	
	open func urlForResourceType(_ type: ResourceType) -> URL {
		return baseURL.appendingPathComponent(type)
	}
	
	open func urlForRelationship<T: Resource>(_ relationship: Relationship, ofResource resource: T) -> URL {
		if let selfURL = resource.relationships[relationship.name]?.selfURL {
			return selfURL
		}
		
		let resourceURL = resource.url ?? urlForResourceType(resource.resourceType).appendingPathComponent("/\(resource.id!)")
		let key = keyFormatter.format(relationship)
		let urlString = resourceURL.appendingPathComponent("/relationships/\(key)").absoluteString
		return URL(string: urlString, relativeTo: baseURL)!
	}
	
	open func urlForQuery<T: Resource>(_ query: Query<T>) -> URL {
		let url: URL
		let preBuiltURL: Bool
		
		// Base URL
		if let urlString = query.url?.absoluteString {
			url = URL(string: urlString, relativeTo: baseURL)!
			preBuiltURL = true
		} else if let type = query.resourceType {
			url = urlForResourceType(type)
			preBuiltURL = false
		} else {
			preconditionFailure("Cannot build URL for query. Query does not have a URL, nor a resource type.")
		}
		
		var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)!
		var queryItems: [URLQueryItem] = urlComponents.queryItems ?? []
		
		// Resource IDs
		if !preBuiltURL {
			if let ids = query.resourceIDs {
				if ids.count == 1 {
					urlComponents.path = (urlComponents.path as NSString).appendingPathComponent(ids.first!)
				} else {
					let item = URLQueryItem(name: "filter[id]", value: ids.joined(separator: ","))
					appendQueryItem(item, to: &queryItems)
				}
			}
		}
		
		// Includes
		if !query.includes.isEmpty {
			var resolvedIncludes = [String]()
			
			for include in query.includes {
				var keys = [String]()
				
				var relatedResourceType: Resource.Type = T.self
				for part in include.components(separatedBy: ".") {
					if let relationship = relatedResourceType.field(named: part) as? Relationship {
						keys.append(keyFormatter.format(relationship))
						relatedResourceType = relationship.linkedType
					}
				}
				
				resolvedIncludes.append(keys.joined(separator: "."))
			}
			
			let item = URLQueryItem(name: "include", value: resolvedIncludes.joined(separator: ","))
			appendQueryItem(item, to: &queryItems)
		}
		
		// Filters
		for filter in query.filters {
			let fieldName = filter.leftExpression.keyPath
			var item: URLQueryItem?
			if let field = T.field(named: fieldName) {
				item = queryItemForFilter(on: keyFormatter.format(field), value: filter.rightExpression.constantValue, operatorType: filter.predicateOperatorType)
			} else {
				item = queryItemForFilter(on: fieldName, value: filter.rightExpression.constantValue, operatorType: filter.predicateOperatorType)
			}
			appendQueryItem(item!, to: &queryItems)
		}
		
		// Fields
		for (resourceType, fields) in query.fields {
			let keys = fields.map { fieldName in
				return keyFormatter.format(fieldName)
			}
			let item = URLQueryItem(name: "fields[\(resourceType)]", value: keys.joined(separator: ","))
			appendQueryItem(item, to: &queryItems)
		}
		
		// Sorting
		if !query.sortDescriptors.isEmpty {
			let descriptorStrings = query.sortDescriptors.map { descriptor -> String in
				let field = T.field(named: descriptor.key!)
				let key = self.keyFormatter.format(field!)
				if descriptor.ascending {
					return key
				} else {
					return "-\(key)"
				}
			}
			
			let item = URLQueryItem(name: "sort", value: descriptorStrings.joined(separator: ","))
			appendQueryItem(item, to: &queryItems)
		}
		
		// Pagination
		if let pagination = query.pagination {
			for item in queryItemsForPagination(pagination) {
				appendQueryItem(item, to: &queryItems)
			}
		}

		// Compose URL
		if !queryItems.isEmpty {
			urlComponents.queryItems = queryItems
		}
		
		return urlComponents.url!
	}

	/**
	Returns an URLQueryItem that represents a filter in a URL.
	By default this method only supports 'equal to' predicates. You can override this method to add support for other filtering strategies.
	It uses the String(describing:) method to convert values to strings. If `value` is nil, a string "null" will be used. Arrays will be
	represented as "firstValue,secondValue,thirdValue".

	- parameter key:          The key that is filtered.
	- parameter value:        The value on which is filtered.
	- parameter operatorType: The NSPredicateOperatorType for the filter.

	- returns: A URLQueryItem representing the filter.
	*/
	open func queryItemForFilter(on key: String, value: Any?, operatorType: NSComparisonPredicate.Operator) -> URLQueryItem {
		assert(operatorType == .equalTo, "The built in router only supports Query filter expressions of type 'equalTo'")
		let stringValue: String
		if let valueArray = value as? [Any] {
			stringValue = valueArray.map { String(describing: $0) }.joined(separator: ",")
		} else if let value = value {
			stringValue = String(describing: value)
		} else {
			stringValue = "null"
		}
		return URLQueryItem(name: "filter[\(key)]", value: stringValue)
	}

	/**
	Returns an array of URLQueryItems that represent the given pagination configuration.
	By default this method only supports the PageBasedPagination and OffsetBasedPagination configurations.
	You can override this method to add support for other pagination strategies.
	
	- parameter pagination: The QueryPagination configuration.
	
	- returns: Array of URLQueryItems.
	*/
	open func queryItemsForPagination(_ pagination: Pagination) -> [URLQueryItem] {
		var queryItems = [URLQueryItem]()
		
		switch pagination {
		case let pagination as PageBasedPagination:
			queryItems.append(URLQueryItem(name: "page[number]", value: String(pagination.pageNumber)))
			queryItems.append(URLQueryItem(name: "page[size]", value: String(pagination.pageSize)))
		case let pagination as OffsetBasedPagination:
			queryItems.append(URLQueryItem(name: "page[offset]", value: String(pagination.offset)))
			queryItems.append(URLQueryItem(name: "page[limit]", value: String(pagination.limit)))
		default:
			assertionFailure("The built in router only supports PageBasedPagination and OffsetBasedPagination")
		}
		
		return queryItems
	}
	
	fileprivate func appendQueryItem(_ queryItem: URLQueryItem, to queryItems: inout [URLQueryItem]) {
		queryItems = queryItems.filter { return $0.name != queryItem.name }
		queryItems.append(queryItem)
	}
}
