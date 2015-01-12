//
//  Store.swift
//  Spine
//
//  Created by Ward van Teijlingen on 30-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation

class Store: ArrayLiteralConvertible, SequenceType, Printable, DebugPrintable {
	private var objectsByType: [String : [ResourceProtocol]] = [:]
	private var objectsByTypeAndID: [String : [String: ResourceProtocol]] = [:]
	
	init(objects: [ResourceProtocol]) {
		for object in objects {
			self.add(object)
		}
	}
	
	// MARK: ArrayLiteralConvertible protocol
	
	required init(arrayLiteral elements: ResourceProtocol...) {
		for element in elements {
			self.add(element)
		}
	}
	
	// MARK: Mutating
	
	func add(object: ResourceProtocol) {
		if let id = object.id {
			let type = object.type
			
			if (self.objectsByTypeAndID[type] == nil) {
				self.objectsByTypeAndID[type] = [:]
			}
			self.objectsByTypeAndID[type]![id] = object
			
			if (self.objectsByType[type] == nil) {
				self.objectsByType[type] = []
			}
			self.objectsByType[type]!.append(object)
		} else {
			assertionFailure("Store can only store objects that are have an id.")
		}
	}
	
	func remove(object: ResourceProtocol) {
		if let id = object.id {
			let type = object.type
			
			if self.objectsByTypeAndID[type] != nil {
				self.objectsByTypeAndID[type]![id] = nil
			}
			
			if (self.objectsByType[type] != nil) {
				self.objectsByType[type] = self.objectsByType[type]!.filter { orderedObject in
					return orderedObject.id == object.id
				}
			}
		} else {
			assertionFailure("Store can only remove objects that have an id.")
		}
	}
	
	// MARK: Fetching
	
	func objectWithType(type: String, identifier: String) -> ResourceProtocol? {
		if let objects = self.objectsByTypeAndID[type] {
			if let object = objects[identifier] {
				return object
			}
		}
		
		return nil
	}
	
	func allObjectsWithType(type: String) -> [ResourceProtocol] {
		return self.objectsByType[type] ?? []
	}
	
	func allObjects() -> [ResourceProtocol] {
		var allObjects: [ResourceProtocol] = []
		
		for (type, objects) in self.objectsByType {
			allObjects += objects
		}
		
		return allObjects
	}
	
	// MARK: Printable protocol
	
	var description: String {
		var string = ""
		for object in self.allObjects() {
			string += "\(object.type)[\(object.id)]\n"
		}
		
		return string
	}
	
	// MARK: DebugPrintable protocol
	
	var debugDescription: String {
		return description
	}
	
	// MARK: SequenceType protocol
	
	func generate() -> GeneratorOf<ResourceProtocol> {
		var allObjects = self.allObjects()
		var index = -1

		return GeneratorOf<ResourceProtocol> {
			index++
			
			if (index > allObjects.count - 1) {
				return nil
			}
		
			return allObjects[index]
		}
	}
	
	
	// MARK: Dispensing
	
	var resourceFactory: ResourceFactory!
	
	func dispenseResourceWithType(type: String, id: String? = nil, useFirst: Bool = false) -> ResourceProtocol {
		var resource: ResourceProtocol
		var isExistingResource: Bool
		
		if let existingResource = objectWithType(type, identifier: id!) {
			resource = existingResource
			isExistingResource = true
			
		} else if useFirst {
			if let existingResource = allObjectsWithType(type).first {
				resource = existingResource
				isExistingResource = true
			} else {
				resource = resourceFactory.instantiate(type)
				resource.id = id
				isExistingResource = false
			}
			
		} else {
			resource = resourceFactory.instantiate(type)
			resource.id = id
			isExistingResource = false
		}
		
		// Add resource to store if needed
		if !isExistingResource {
			add(resource)
		}
		
		return resource
	}
}