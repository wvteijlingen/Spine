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
	var baseURL: NSURL! { get set }
	var keyFormatter: KeyFormatter! { get set }
	
	/**
	Returns an NSURL that points to the collection of resources with a given type.
	
	- parameter type: The type of resources.
	
	- returns: The NSURL.
	*/
	func URLForResourceType(type: ResourceType) -> NSURL
	
	/**
	Returns an NSURL that represents the given query.
	
	- parameter query: The query to turn into an NSURL.
	
	- returns: The NSURL.
	*/
	func URLForQuery<T: Resource>(query: Query<T>) -> NSURL
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
public class JSONAPIRouter: Router {
	public var baseURL: NSURL!
	public var keyFormatter: KeyFormatter!

	public init() { }
	
	public func URLForResourceType(type: ResourceType) -> NSURL {
		return baseURL.URLByAppendingPathComponent(type)
	}
	
	public func URLForQuery<T: Resource>(query: Query<T>) -> NSURL {
		var URL: NSURL!
		var preBuiltURL = false
		
		// Base URL
		if let URLString = query.URL?.absoluteString {
			URL = NSURL(string: URLString, relativeToURL: baseURL)
			preBuiltURL = true
		} else if let type = query.resourceType {
			URL = URLForResourceType(type)
		} else {
			assertionFailure("Cannot build URL for query. Query does not have a URL, nor a resource type.")
		}
		
		let URLComponents = NSURLComponents(URL: URL, resolvingAgainstBaseURL: true)!
		var queryItems: [NSURLQueryItem] = URLComponents.queryItems ?? []
		
		// Resource IDs
		if !preBuiltURL {
			if let IDs = query.resourceIDs {
				if IDs.count == 1 {
					URLComponents.path = (URLComponents.path! as NSString).stringByAppendingPathComponent(IDs.first!)
				} else {
					let item = NSURLQueryItem(name: "filter[id]", value: IDs.joinWithSeparator(","))
					setQueryItem(item, forQueryItems: &queryItems)
				}
			}
		}
		
		// Includes
		if !query.includes.isEmpty {
			var resolvedIncludes = [String]()
			
			for include in query.includes {
				var keys = [String]()
				
				var relatedResourceType: Resource.Type = T.self
				for part in include.componentsSeparatedByString(".") {
					if let relationship = relatedResourceType.fieldNamed(part) as? Relationship {
						keys.append(keyFormatter.format(relationship))
						relatedResourceType = relationship.linkedType
					}
				}
				
				resolvedIncludes.append(keys.joinWithSeparator("."))
			}
			
			let item = NSURLQueryItem(name: "include", value: resolvedIncludes.joinWithSeparator(","))
			setQueryItem(item, forQueryItems: &queryItems)
		}
		
		// Filters
		for filter in query.filters {
			let fieldName = filter.leftExpression.keyPath
			let item = queryItemForFilter(T.fieldNamed(fieldName)!, value: filter.rightExpression.constantValue, operatorType: filter.predicateOperatorType)
			setQueryItem(item, forQueryItems: &queryItems)
		}
		
		// Fields
		for (resourceType, fields) in query.fields {
			let keys = fields.map { fieldName in
				return keyFormatter.format(T.fieldNamed(fieldName)!)
			}
			let item = NSURLQueryItem(name: "fields[\(resourceType)]", value: keys.joinWithSeparator(","))
			setQueryItem(item, forQueryItems: &queryItems)
		}
		
		// Sorting
		if !query.sortDescriptors.isEmpty {
			let descriptorStrings = query.sortDescriptors.map { descriptor -> String in
				let field = T.fieldNamed(descriptor.key!)
				let key = self.keyFormatter.format(field!)
				if descriptor.ascending {
					return "+\(key)"
				} else {
					return "-\(key)"
				}
			}
			
			let item = NSURLQueryItem(name: "sort", value: descriptorStrings.joinWithSeparator(","))
			setQueryItem(item, forQueryItems: &queryItems)
		}
		
		// Pagination
		if let pagination = query.pagination {
			for item in queryItemsForPagination(pagination) {
				setQueryItem(item, forQueryItems: &queryItems)
			}
		}

		// Compose URL
		if !queryItems.isEmpty {
			URLComponents.queryItems = queryItems
		}
		
		return URLComponents.URL!
	}
	
	/**
	Returns an NSURLQueryItem that represents a filter in a URL.
	By default this method only supports 'equal to' predicates. You can override
	this method to add support for other filtering strategies.
	
	- parameter field:        The field that is filtered.
	- parameter value:        The value on which is filtered.
	- parameter operatorType: The NSPredicateOperatorType for the filter.
	
	- returns: An NSURLQueryItem representing the filter.
	*/
	
	public func queryItemForFilter(field: Field, value: AnyObject, operatorType: NSPredicateOperatorType) -> NSURLQueryItem {
		assert(operatorType == .EqualToPredicateOperatorType, "The built in router only supports Query filter expressions of type 'equalTo'")
		let key = keyFormatter.format(field)
		return NSURLQueryItem(name: "filter[\(key)]", value: "\(value)")
	}

	/**
	Returns an array of NSURLQueryItems that represent the given pagination configuration.
	By default this method only supports the PageBasedPagination and OffsetBasedPagination configurations.
	You can override this method to add support for other pagination strategies.
	
	- parameter pagination: The QueryPagination configuration.
	
	- returns: Array of NSURLQueryItems.
	*/
	public func queryItemsForPagination(pagination: Pagination) -> [NSURLQueryItem] {
		var queryItems = [NSURLQueryItem]()
		
		switch pagination {
		case let pagination as PageBasedPagination:
			queryItems.append(NSURLQueryItem(name: "page[number]", value: String(pagination.pageNumber)))
			queryItems.append(NSURLQueryItem(name: "page[size]", value: String(pagination.pageSize)))
			
		case let pagination as OffsetBasedPagination:
			queryItems.append(NSURLQueryItem(name: "page[offset]", value: String(pagination.offset)))
			queryItems.append(NSURLQueryItem(name: "page[limit]", value: String(pagination.limit)))
			
			
		default:
			assertionFailure("The built in router only supports PageBasedPagination and OffsetBasedPagination")
		}
		
		return queryItems
	}
	
	private func setQueryItem(queryItem: NSURLQueryItem, inout forQueryItems queryItems: [NSURLQueryItem]) {
		queryItems = queryItems.filter { return $0.name != queryItem.name }
		queryItems.append(queryItem)
	}
}