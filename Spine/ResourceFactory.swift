//
//  ResourceFactory.swift
//  Spine
//
//  Created by Ward van Teijlingen on 06/01/16.
//  Copyright © 2016 Ward van Teijlingen. All rights reserved.
//

import Foundation

/**
A ResourceFactory creates resources from given factory funtions.
*/
struct ResourceFactory {
	
	private var resourceTypes: [ResourceType: Resource.Type] = [:]
	
	/**
	Registers a given factory function that creates resource with a given type.
	Registering a function for an already registered resource type will override that factory function.
	
	- parameter type:    The resource type for which to register a factory function.
	- parameter factory: The factory function that returns a resource.
	*/
	mutating func registerResource(resourceClass: Resource.Type) {
		resourceTypes[resourceClass.resourceType] = resourceClass
	}
	
	/**
	Instantiates a resource with the given type, by using a registered factory function.
	
	- parameter type: The resource type to instantiate.
	
	- returns: An instantiated resource.
	*/
	func instantiate(type: ResourceType) -> Resource {
		assert(resourceTypes[type] != nil, "Cannot instantiate resource of type \(type). You must register this type with Spine first.")
		return resourceTypes[type]!.init()
	}
	
	/**
	Dispenses a resource with the given type and id, optionally by finding it in a pool of existing resource instances.
	
	This methods tries to find a resource with the given type and id in the pool. If no matching resource is found,
	it tries to find the nth resource, indicated by `index`, of the given type from the pool. If still no resource is found,
	it instantiates a new resource with the given id and adds this to the pool.
	
	- parameter type:  The resource type to dispense.
	- parameter id:    The id of the resource to dispense.
	- parameter pool:  An array of resources in which to find exisiting matching resources.
	- parameter index: Optional index of the resource in the pool.
	
	- returns: A resource with the given type and id.
	*/
	func dispense(type: ResourceType, id: String, inout pool: [Resource], index: Int? = nil) -> Resource {
		var resource: Resource! = pool.filter { $0.resourceType == type && $0.id == id }.first
		
		if resource == nil && index != nil && !pool.isEmpty {
			let applicableResources = pool.filter { $0.resourceType == type }
			if index! < applicableResources.count {
				resource = applicableResources[index!]
			}
		}
		
		if resource == nil {
			resource = instantiate(type)
			resource.id = id
			pool.append(resource)
		}
		
		return resource
	}
}