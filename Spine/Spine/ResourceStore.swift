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
		assert(resource.id != nil, "ResourceStore can only store resources with a id.")
		
		let type = resource.type
		
		if (self.resources[type] == nil) {
			self.resources[type] = [:]
		}
		self.resources[type]![resource.id!] = resource
		
		if (self.orderedResources[type] == nil) {
			self.orderedResources[type] = []
		}
		self.orderedResources[type]!.append(resource)
	}
	
	func remove(resource: Resource) {
		assert(resource.id != nil, "ResourceStore can only store resources with a id.")
		
		let type = resource.type
		
		if self.resources[type] != nil {
			self.resources[type]![resource.id!] = nil
		}
		
		if (self.orderedResources[type] != nil) {
			self.orderedResources[type] = self.orderedResources[type]!.filter { orderedResource in
				return orderedResource.id == resource.id
			}
		}
	}
	
	func resource(type: String, identifier: String) -> Resource? {
		if let resources = self.resources[type] {
			if let resource = resources[identifier] {
				return resource
			}
		}
		
		return nil
	}
	
	func containsResourceWithType(type: String, identifier: String) -> Bool {
		if let resources = self.resources[type] {
			if let resource = resources[identifier] {
				return true
			}
		}
		
		return false
	}
	
	func resourcesWithName(type: String) -> [Resource] {
		return self.orderedResources[type] ?? []
	}
	
	func allResources() -> [Resource] {
		var allResources: [Resource] = []
		
		for (type, resources) in self.orderedResources {
			allResources += resources
		}
		
		return allResources
	}
	
	public var description: String {
		var string = ""
		for resource in self.allResources() {
			string += "\(resource.type)[\(resource.id)]\n"
		}
		
		return string
	}
}