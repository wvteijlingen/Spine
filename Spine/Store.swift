//
//  Store.swift
//  Spine
//
//  Created by Ward van Teijlingen on 30-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation

class Store: ArrayLiteralConvertible, SequenceType, Printable, DebugPrintable {
	private var objectsByType: [String : [Resource]] = [:]
	private var objectsByTypeAndID: [String : [String: Resource]] = [:]
	
	init(objects: [Resource]) {
		for object in objects {
			self.add(object)
		}
	}
	
	// MARK: ArrayLiteralConvertible protocol
	
	required init(arrayLiteral elements: Resource...) {
		for element in elements {
			self.add(element)
		}
	}
	
	// MARK: Mutating
	
	func add(object: Resource) {
		if let id = object.id {
			let type = object.dynamicType.type
			
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
	
	func remove(object: Resource) {
		if let id = object.id {
			let type = object.dynamicType.type
			
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
	
	func objectWithType(type: String, identifier: String) -> Resource? {
		if let objects = self.objectsByTypeAndID[type] {
			if let object = objects[identifier] {
				return object
			}
		}
		
		return nil
	}
	
	func allObjectsWithType(type: String) -> [Resource] {
		return self.objectsByType[type] ?? []
	}
	
	func allObjects() -> [Resource] {
		var allObjects: [Resource] = []
		
		for (type, objects) in self.objectsByType {
			allObjects += objects
		}
		
		return allObjects
	}
	
	// MARK: Printable protocol
	
	var description: String {
		var string = ""
		for object in self.allObjects() {
			string += "\(object.dynamicType.type)[\(object.id)]\n"
		}
		
		return string
	}
	
	// MARK: DebugPrintable protocol
	
	var debugDescription: String {
		return description
	}
	
	// MARK: SequenceType protocol
	
	func generate() -> GeneratorOf<Resource> {
		var allObjects = self.allObjects()
		var index = -1

		return GeneratorOf<Resource> {
			index++
			
			if (index > allObjects.count - 1) {
				return nil
			}
		
			return allObjects[index]
		}
	}
	
	
	// MARK: Dispensing
	
	var classMap: ResourceClassMap!
	
	func dispenseResourceWithType(type: String, id: String? = nil, useFirst: Bool = false) -> Resource {
		if id == nil {
			return self.classMap[type]() as Resource
		}
		
		var resource: Resource
		var isExistingResource: Bool
		
		if let existingResource = objectWithType(type, identifier: id!) {
			resource = existingResource
			isExistingResource = true
			
		} else if useFirst {
			if let existingResource = allObjectsWithType(type).first {
				resource = existingResource
				isExistingResource = true
			} else {
				resource = classMap[type]() as Resource
				resource.id = id
				isExistingResource = false
			}
			
		} else {
			resource = classMap[type]() as Resource
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