//
//  Store.swift
//  Spine
//
//  Created by Ward van Teijlingen on 30-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation

class Store<T:Identifiable>: ArrayLiteralConvertible, SequenceType, Printable {
	private var objectsByType: [String : [T]] = [:]
	private var objectsByTypeAndID: [String : [String: T]] = [:]
	
	// MARK: Intializers
	
	init() {

	}
	
	init(objects: [T]) {
		for object in objects {
			self.add(object)
		}
	}
	
	// MARK: ArrayLiteralConvertible protocol
	
	required init(arrayLiteral elements: T...) {
		for element in elements {
			self.add(element)
		}
	}
	
	// MARK: Mutating
	
	func add(object: T) {
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
	
	func remove(object: T) {
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
	
	func objectWithType(type: String, identifier: String) -> T? {
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
	
	func allObjectsWithType(type: String) -> [T] {
		return self.objectsByType[type] ?? []
	}
	
	func allObjects() -> [T] {
		var allObjects: [T] = []
		
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
	
	func generate() -> GeneratorOf<T> {
		var allObjects = self.allObjects()
		var index = -1

		return GeneratorOf<T> {
			index++
			
			if (index > allObjects.count - 1) {
				return nil
			}
		
			return allObjects[index]
		}
	}
}