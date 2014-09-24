//
//  ResourceStore.swift
//  Spine
//
//  Created by Ward van Teijlingen on 30-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation

public class ResourceStore: Printable {
	private var orderedResources: [String : [Resource]] = [:]
	private var resources: [String : [String: Resource]] = [:]
	
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
		
		if (self.orderedResources[resourceType] == nil) {
			self.orderedResources[resourceType] = []
		}
		self.orderedResources[resourceType]!.append(resource)
	}
	
	func remove(resource: Resource) {
		assert(resource.resourceID != nil, "ResourceStore can only store resources with a resourceID.")
		
		let resourceType = resource.resourceType
		
		if self.resources[resourceType] != nil {
			self.resources[resourceType]![resource.resourceID!] = nil
		}
		
		if (self.orderedResources[resourceType] != nil) {
			self.orderedResources[resourceType] = self.orderedResources[resourceType]!.filter { orderedResource in
				return orderedResource.resourceID == resource.resourceID
			}
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
		return self.orderedResources[resourceType] ?? []
	}
	
	func allResources() -> [Resource] {
		var allResources: [Resource] = []
		
		for (resourceType, resources) in self.orderedResources {
			allResources += resources
		}
		
		return allResources
	}
	
	public var description: String {
		var string = ""
		for resource in self.allResources() {
			string += "\(resource.resourceType)[\(resource.resourceID)]\n"
		}
		
		return string
	}
}