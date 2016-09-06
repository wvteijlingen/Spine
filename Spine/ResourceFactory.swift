//
//  ResourceFactory.swift
//  Spine
//
//  Created by Ward van Teijlingen on 06/01/16.
//  Copyright © 2016 Ward van Teijlingen. All rights reserved.
//

import Foundation


/// A ResourceFactory creates resources from given factory funtions.
struct ResourceFactory {
	
	fileprivate var resourceTypes: [ResourceType: Resource.Type] = [:]

	/// Registers a given resource type so it can be instantiated by the factory.
	/// Registering a type that was alsreay registered will override it.
	///
	/// - parameter resourceClass: <#resourceClass description#>
	mutating func registerResource(_ type: Resource.Type) {
		resourceTypes[type.resourceType] = type
	}

	/// Instantiates a resource with the given type, by using a registered factory function.
	///
	/// - parameter type: The resource type to instantiate.
	///
	/// - throws: A SerializerError.resourceTypeUnregistered erro when the type is not registered.
	///
	/// - returns: An instantiated resource.
	func instantiate(_ type: ResourceType) throws -> Resource {
		if resourceTypes[type] == nil {
			throw SerializerError.resourceTypeUnregistered(type)
		}
		return resourceTypes[type]!.init()
	}

	
	/// Dispenses a resource with the given type and id, optionally by finding it in a pool of existing resource instances.
	///
	/// This methods tries to find a resource with the given type and id in the pool. If no matching resource is found,
	/// it tries to find the nth resource, indicated by `index`, of the given type from the pool. If still no resource is found,
	/// it instantiates a new resource with the given id and adds this to the pool.
	///
	/// - parameter type:  The resource type to dispense.
	/// - parameter id:    The id of the resource to dispense.
	/// - parameter pool:  An array of resources in which to find exisiting matching resources.
	/// - parameter index: Optional index of the resource in the pool.
	///
	/// - throws: A SerializerError.resourceTypeUnregistered erro when the type is not registered.
	///
	/// - returns: A resource with the given type and id.
	func dispense(_ type: ResourceType, id: String, pool: inout [Resource], index: Int? = nil) throws -> Resource {
		var resource: Resource! = pool.filter { $0.resourceType == type && $0.id == id }.first
		
		if resource == nil && index != nil && !pool.isEmpty {
			let applicableResources = pool.filter { $0.resourceType == type }
			if index! < applicableResources.count {
				resource = applicableResources[index!]
			}
		}
		
		if resource == nil {
			resource = try instantiate(type)
			resource.id = id
			pool.append(resource)
		}
		
		return resource
	}
}
