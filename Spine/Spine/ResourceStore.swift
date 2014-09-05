//
//  ResourceStore.swift
//  Spine
//
//  Created by Ward van Teijlingen on 30-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation

class ResourceStore: Printable {
	var resources: [String : [String: Resource]] = [:]
	
	init() {
		
	}
	
	init(resources: [Resource]) {
		for resource in resources {
			self.add(resource)
		}
	}
	
	func add(resource: Resource) {
		assert(resource.resourceID != nil, "ResourceStore can only store resources with a resourceID.")
		
		let resourceType = resource.resourceType
		if (self.resources[resourceType] == nil) {
			self.resources[resourceType] = [:]
		}
		self.resources[resourceType]![resource.resourceID!] = resource
	}
	
	func remove(resource: Resource) {
		assert(resource.resourceID != nil, "ResourceStore can only store resources with a resourceID.")
		
		if self.resources[resource.resourceType] != nil {
			self.resources[resource.resourceType]![resource.resourceID!] = nil
		}
	}
	
	func resource(resourceType: String, identifier: String) -> Resource? {
		if let resources = self.resources[resourceType] {
			if let resource = resources[identifier] {
				return resource
			}
		}
		
		return nil
	}
	
	func containsResourceWithType(resourceType: String, identifier: String) -> Bool {
		if let resources = self.resources[resourceType] {
			if let resource = resources[identifier] {
				return true
			}
		}
		
		return false
	}
	
	func resourcesWithName(resourceType: String) -> [Resource] {
		var resources: [Resource] = []
		
		if let resourcesByID: [String: Resource] = self.resources[resourceType] {
			for value in resourcesByID.values {
				resources.append(value)
			}
		}
		
		return resources
	}
	
	func allResources() -> [Resource] {
		var resources: [Resource] = []
		
		for (resourceType, resourcesByID) in self.resources {
			resources += resourcesByID.values
		}
		
		return resources
	}
	
	var description: String {
		var string = ""
			for (resourceType, resources) in self.resources {
				for (resourceID, resource) in resources {
					string += "\(resourceType)[\(resourceID)]\n"
				}
			}
			
			return string
	}
}