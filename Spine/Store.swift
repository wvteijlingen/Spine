//
//  Store.swift
//  Spine
//
//  Created by Ward van Teijlingen on 30-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation

class Store: ArrayLiteralConvertible, SequenceType, Printable {
	private var objectsByType: [String : [Resource]] = [:]
	private var objectsByTypeAndID: [String : [String: Resource]] = [:]
	
	// MARK: Intializers
	
	init() {

	}
	
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
		if let identifier = object.uniqueIdentifier {
			let type = identifier.type
			
			if (self.objectsByTypeAndID[type] == nil) {
				self.objectsByTypeAndID[type] = [:]
			}
			self.objectsByTypeAndID[type]![identifier.id] = object
			
			if (self.objectsByType[type] == nil) {
				self.objectsByType[type] = []
			}
			self.objectsByType[type]!.append(object)
		} else {
			assertionFailure("Store can only store objects that are uniquely identifiable.")
		}
	}
	
	func remove(object: Resource) {
		if let identifier = object.uniqueIdentifier {
			let type = identifier.type
			
			if self.objectsByTypeAndID[type] != nil {
				self.objectsByTypeAndID[type]![identifier.id] = nil
			}
			
			if (self.objectsByType[type] != nil) {
				self.objectsByType[type] = self.objectsByType[type]!.filter { orderedObject in
					return orderedObject.id == object.id
				}
			}
		} else {
			assertionFailure("Store can only remove objects that are uniquely identifiable.")
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
	
	func containsObjectWithType(type: String, identifier: String) -> Bool {
		if let objects = self.objectsByTypeAndID[type] {
			if let object = objects[identifier] {
				return true
			}
		}
		
		return false
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
			string += "\(object.type)[\(object.id)]\n"
		}
		
		return string
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
}