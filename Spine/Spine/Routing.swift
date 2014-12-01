//
//  Routing.swift
//  Spine
//
//  Created by Ward van Teijlingen on 24-09-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation

class JSONAPIRouter {
	var baseURL: String = ""
	
	func URLForCollectionOfResourceType(resourceType: String) -> String {
		return "\(self.baseURL)/\(resourceType)"
	}
	
	func URLForResourceWithType(resourceType: String, ID: String) -> String {
		return "\(self.baseURL)/\(resourceType)/\(ID)"
	}
	
	func URLForResourcesWithType(resourceType: String, IDs: [String]) -> String {
		let joinedIDs = join(",", IDs)
		return "\(self.baseURL)/\(resourceType)/\(joinedIDs)"
	}
	
	func URLForResource(resource: Resource) -> String {
		if let resourceLocation = resource.href {
			return resourceLocation
		}
		
		assert(resource.uniqueIdentifier != nil, "Resource does not have an href, nor a unique identifier.")
		
		return "\(self.baseURL)/\(resource.uniqueIdentifier!.type)/\(resource.uniqueIdentifier!.id)"
	}
	
	func URLForQuery(query: Query) -> String {
		return query.URLRelativeToURL(self.baseURL)
	}
}