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
		return URLForResourceType(resource.type).URLByAppendingPathComponent("links/\(relationship)")
	}
	
	func URLForRelationship(relationship: String, ofResource resource: ResourceProtocol, ids: [String]) -> NSURL {
		var URL = URLForRelationship(relationship, ofResource: resource)
		return URL.URLByAppendingPathComponent(",".join(ids))
	}
	
	func URLForQuery<T: ResourceProtocol>(query: Query<T>) -> NSURL {
		var URL: NSURL!
		
		// Base URL
		if let baseURL = query.URL {
			if baseURL.host == nil {
				URL = NSURL(string: baseURL.absoluteString!, relativeToURL: self.baseURL)
			} else {
				URL = baseURL
			}
		} else {
			URL = self.baseURL.URLByAppendingPathComponent(query.resourceType, isDirectory: true)
		}
		
		// Resource IDs
		if let IDs = query.resourceIDs {
			URL = URL.URLByAppendingPathComponent(join(",", IDs), isDirectory: false)
		}
		
		var URLComponents = NSURLComponents(URL: URL, resolvingAgainstBaseURL: true)!
		var queryItems: [NSURLQueryItem] = []
		
		if let existingQueryItems = URLComponents.queryItems {
			queryItems = existingQueryItems as [NSURLQueryItem]
		}
		
		// Includes
		if query.includes.count != 0 {
			var item = NSURLQueryItem(name: "include", value: ",".join(query.includes))
			self.setQueryItem(item, forQueryItems: &queryItems)
		}
		
		// Filters
		for filter in query.filters {
			var item = NSURLQueryItem(name: filter.key, value: filter.rhs)
			self.setQueryItem(item, forQueryItems: &queryItems)
		}
		
		// Fields
		for (resourceType, fields) in query.fields {
			var item = NSURLQueryItem(name: "fields[\(resourceType)]", value: ",".join(fields))
			self.setQueryItem(item, forQueryItems: &queryItems)
		}
		
		// Sorting
		if query.sortOrders.count != 0 {
			var item = NSURLQueryItem(name: "sort", value: ",".join(query.sortOrders))
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