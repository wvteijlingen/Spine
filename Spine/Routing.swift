//
//  Routing.swift
//  Spine
//
//  Created by Ward van Teijlingen on 24-09-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation

protocol Router {
	var baseURL: NSURL! { get set }
	
	func URLForResourceType(type: String) -> NSURL
	func URLForRelationship(relationship: String, ofResource resource: ResourceProtocol) -> NSURL
	func URLForRelationship(relationship: String, ofResource resource: ResourceProtocol, ids: [String]) -> NSURL
	func URLForQuery<T: ResourceProtocol>(query: Query<T>) -> NSURL
}

class JSONAPIRouter: Router {
	var baseURL: NSURL! = nil
	
	func URLForResourceType(type: String) -> NSURL {
		return baseURL.URLByAppendingPathComponent(type)
	}
	
	func URLForRelationship(relationship: String, ofResource resource: ResourceProtocol) -> NSURL {
		assert(resource.id != nil, "Cannot build URL for relationship for resource without id: \(resource)")
		return URLForResourceType(resource.type).URLByAppendingPathComponent("/\(resource.id!)/links/\(relationship)")
	}
	
	func URLForRelationship(relationship: String, ofResource resource: ResourceProtocol, ids: [String]) -> NSURL {
		var URL = URLForRelationship(relationship, ofResource: resource)
		return URL.URLByAppendingPathComponent(",".join(ids))
	}
	
	func URLForQuery<T: ResourceProtocol>(query: Query<T>) -> NSURL {
		var URL: NSURL!
		
		// Base URL
		if let queryURL = query.URL {
			URL = NSURL(string: queryURL.absoluteString!, relativeToURL: self.baseURL)
		} else if let type = query.resourceType {
			URL = self.baseURL.URLByAppendingPathComponent(type, isDirectory: true)
		} else {
			assertionFailure("Cannot build URL for query. Query does not have a URL, nor a resource type.")
		}
		
		var URLComponents = NSURLComponents(URL: URL, resolvingAgainstBaseURL: true)!
		var queryItems: [NSURLQueryItem] = []
		
		if let existingQueryItems = URLComponents.queryItems {
			queryItems = existingQueryItems as [NSURLQueryItem]
		}
		
		// Resource IDs
		if let IDs = query.resourceIDs {
			var item = NSURLQueryItem(name: "filter[id]", value: join(",", IDs))
			self.setQueryItem(item, forQueryItems: &queryItems)
		}
		
		// Includes
		if query.includes.count != 0 {
			var item = NSURLQueryItem(name: "include", value: ",".join(query.includes))
			self.setQueryItem(item, forQueryItems: &queryItems)
		}
		
		// Filters
		for filter in query.filters {
			var item = NSURLQueryItem(name: "filter[\(filter.leftExpression.keyPath)]", value: "\(filter.rightExpression.constantValue)")
			self.setQueryItem(item, forQueryItems: &queryItems)
		}
		
		// Fields
		for (resourceType, fields) in query.fields {
			var item = NSURLQueryItem(name: "fields[\(resourceType)]", value: ",".join(fields))
			self.setQueryItem(item, forQueryItems: &queryItems)
		}
		
		// Sorting
		if query.sortDescriptors.count != 0 {
			let descriptorStrings = query.sortDescriptors.map { descriptor -> String in
				if descriptor.ascending {
					return "+\(descriptor.key)"
				} else {
					return "-\(descriptor.key)"
				}
			}
			
			var item = NSURLQueryItem(name: "sort", value: ",".join(descriptorStrings))
			self.setQueryItem(item, forQueryItems: &queryItems)
		}
		
		// Pagination
		if let page = query.page {
			var item = NSURLQueryItem(name: "page", value: String(page))
			self.setQueryItem(item, forQueryItems: &queryItems)
		}
		
		if let pageSize = query.pageSize {
			var item = NSURLQueryItem(name: "page_size", value: String(pageSize))
			self.setQueryItem(item, forQueryItems: &queryItems)
		}
		
		if queryItems.count > 0 {
			URLComponents.queryItems = queryItems
		}
		
		return URLComponents.URL!
	}
	
	private func setQueryItem(queryItem: NSURLQueryItem, inout forQueryItems queryItems: [NSURLQueryItem]) {
		// Remove old item
		queryItems.filter { return $0.name != queryItem.name }
		queryItems.append(queryItem)
	}
}