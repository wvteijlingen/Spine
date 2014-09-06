//
//  Mapping.swift
//  Spine
//
//  Created by Ward van Teijlingen on 23-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation
import UIKit
import SwiftyJSON

//typealias [String: AnyObject] = [String: AnyObject]

struct ResourceClassMap {
	private var registeredClasses: [String: Resource.Type] = [:]
	
	mutating func registerClass(type: Resource.Type) {
		let instance = type()
		self.registeredClasses[instance.resourceType] = type
	}
	
	mutating func unregisterClass(type: Resource.Type) {
		let instance = type()
		self.registeredClasses[instance.resourceType] = nil
	}
	
	func classForResourceType(resourceType: String) -> Resource.Type {
		return registeredClasses[resourceType]!
	}
	
	subscript(resourceType: String) -> Resource.Type {
		return self.classForResourceType(resourceType)
	}
}


// MARK: -

class Serializer {
	private var classMap: ResourceClassMap = ResourceClassMap()
	
	
	//MARK: Class mapping
	
	func registerClass(type: Resource.Type) {
		self.classMap.registerClass(type)
	}
	
	func unregisterClass(type: Resource.Type) {
		self.classMap.unregisterClass(type)
	}
	
	func classNameForResourceType(resourceType: String) -> Resource.Type {
		return self.classMap[resourceType]
	}
	
	
	// MARK: Serializing

	func deserializeData(data: NSData) -> ResourceStore {
		let mappingOperation = DeserializeOperation(data: data, classMap: self.classMap)
		mappingOperation.start()
		return mappingOperation.result!
	}

	func deserializeData(data: NSData, usingStore store: ResourceStore) -> ResourceStore {
		let mappingOperation = DeserializeOperation(data: data, store: store, classMap: self.classMap)
		mappingOperation.start()
		return mappingOperation.result!
	}
	
	func deserializeError(data: NSData, withResonseStatus responseStatus: Int) -> NSError {
		let JSON = JSONValue(data as NSData!)
		
		let code = JSON["errors"][0]["id"].integer ?? responseStatus
		
		var userInfo: [String : AnyObject]?
		
		if let errorTitle = JSON["errors"][0]["title"].string {
			userInfo = [NSLocalizedDescriptionKey: errorTitle]
		}
		
		return NSError(domain: SPINE_ERROR_DOMAIN, code: code, userInfo: userInfo)
	}

	func serializeResources(resources: [Resource]) -> [String: [[String: AnyObject]]] {
		let mappingOperation = SerializeOperation(resources: resources)
		mappingOperation.start()
		return mappingOperation.result!
	}
}


// MARK: -

class DeserializeOperation: NSOperation {
	
	private var data: JSONValue
	private var store: ResourceStore
	private var classMap: ResourceClassMap
	
	private lazy var formatter = {
		Formatter()
	}()
	
	var result: ResourceStore?
	
	init(data: NSData, classMap: ResourceClassMap) {
		self.data = JSONValue(data as NSData!)
		self.classMap = classMap
		self.store = ResourceStore()
		super.init()
	}
	
	init(data: NSData, store: ResourceStore, classMap: ResourceClassMap) {
		self.data = JSONValue(data as NSData!)
		self.classMap = classMap
		self.store = store
		super.init()
	}
	
	override func main() {
		assert(self.data.object != nil, "The given JSON representation was not of type 'object' (dictionary).")
		
		for(resourceType: String, resourcesData: JSONValue) in self.data.object! {
			if resourceType == "linked" {
				for (linkedResourceType, linkedResources) in resourcesData.object! {
					for representation in linkedResources.array! {
						self.deserializeSingleRepresentation(representation, withResourceType: linkedResourceType)
					}
				}
			} else if let resources = resourcesData.array {
				for representation in resources {
					self.deserializeSingleRepresentation(representation, withResourceType: resourceType)
				}
			}
		}
		
		self.resolveRelations()
		
		self.result = self.store
	}

	/**
	Maps a single resource representation into a resource object of the given type.
	
	:param: representation The JSON representation of a single resource.
	:param: resourceType   The type of resource onto which to map the representation.
	*/
	private func deserializeSingleRepresentation(representation: JSONValue, withResourceType resourceType: String) {
		assert(representation.object != nil, "The given JSON representation was not of type 'object' (dictionary).")
		
		// Find existing resource in the store, or create a new resource.
		var resource: Resource
		var isExistingResource: Bool
		
		if let existingResource = self.store.resource(resourceType, identifier: representation["id"].string!) {
			resource = existingResource
			isExistingResource = true
		} else {
			resource = self.classMap[resourceType]() as Resource
			isExistingResource = false
		}

		// Get the custom attributes and merge them with the default attributes
		var attributes = resource.persistentAttributes
		attributes["resourceID"] = ResourceAttribute(type: .Property, representationName: "id")
		attributes["resourceLocation"] = ResourceAttribute(type: .Property, representationName: "href")
		
		// Deserialize the attributes into the resource object
		for (attributeName, attribute) in attributes {
			let sourceKey = attribute.representationName ?? attributeName
			
			switch attribute.type {
			case .Property, .Date:
				if let value: AnyObject = representation[sourceKey].any {
					resource.setValue(self.formatter.deserialize(value, ofType: attribute.type), forKey: attributeName)
				}
			case .ToOne:
				if let linkData = representation["links"][sourceKey].object {
					if let ID = linkData["id"]?.string {
						let relationship = ResourceRelationship.ToOne(href: linkData["href"]!.string!, ID: ID, type: linkData["type"]!.string!)
						resource.relationships[attributeName] = relationship
					}
				}
			case .ToMany:
				if let linkData = representation["links"][sourceKey].object {
					if let IDs = linkData["ids"]?.array {
						let relationship = ResourceRelationship.ToMany(href: linkData["href"]!.string!, IDs: IDs.map { return $0.string! }, type: linkData["type"]!.string!)
						resource.relationships[attributeName] = relationship
					}
				}
			}
		}

		if !isExistingResource {
			self.store.add(resource)
		}
	}
	
	/**
	Resolves the relations of the resources in the store.
	*/
	private func resolveRelations() {
		for resource in self.store.allResources() {
			
			for (relationshipName: String, relation: ResourceRelationship) in resource.relationships {
				
				switch relation {
				case .ToOne(let href, let ID, let type):
					// Find target of relation in store
					if let targetResource = store.resource(type, identifier: ID) {
						resource.setValue(targetResource, forKey: relationshipName)
					} else {
						// Target resource was not found in store, create a placeholder
						let placeholderResource = self.classMap[type]() as Resource
						placeholderResource.resourceID = ID
						resource.setValue(placeholderResource, forKey: relationshipName)
					}
					
				case .ToMany(let href, let IDs, let type):
					var targetResources: [Resource] = []
					
					// Find targets of relation in store
					for ID in IDs {
						if let targetResource = store.resource(type, identifier: ID) {
							targetResources.append(targetResource)
						} else {
							// Target resource was not found in store, create a placeholder
							let placeholderResource = self.classMap[type]() as Resource
							placeholderResource.resourceID = ID
							targetResources.append(placeholderResource)
						}
						
						resource.setValue(targetResources, forKey: relationshipName)
					}
				}
			}
		}
	}
}


// MARK: -

class SerializeOperation: NSOperation {
	
	private let resources: [Resource]
	private let formatter = Formatter()
	
	var result: [String: [[String: AnyObject]]]?
	
	init(resources: [Resource]) {
		self.resources = resources
	}
	
	override func main() {
		var dictionary: [String: [[String: AnyObject]]] = [:]
		
		//Loop through all resources
		for resource in resources {
			var serializedData: [String: AnyObject] = [:]
			
			// Special attributes
			if let ID = resource.resourceID {
				self.addID(&serializedData, ID: ID)
			}
			
			self.addAttributes(&serializedData, resource: resource)
			self.addRelationships(&serializedData, resource: resource)
			
			//Add the resource representation to the root dictionary
			if dictionary[resource.resourceType] == nil {
				dictionary[resource.resourceType] = [serializedData]
			} else {
				dictionary[resource.resourceType]!.append(serializedData)
			}
		}
		
		self.result = dictionary
	}
	
	// MARK: Special attributes
	
	/**
	Adds the given ID to the passed serialized data.
	
	:param: serializedData The data to add the ID to.
	:param: ID             The ID to add.
	*/
	private func addID(inout serializedData: [String: AnyObject], ID: String) {
		serializedData["id"] = ID
	}
	
	// MARK: Attributes
	
	/**
	Adds the attributes of the the given resource to the passed serialized data.
	
	This method loops over all the attributes in the passed resource, maps the attribute name
	to the key for the serialized form and formats the value of the attribute. It then passes
	the key and value to the addAttribute method.
	
	:param: serializedData The data to add the attributes to.
	:param: resource       The resource whose attributes to add.
	*/
	private func addAttributes(inout serializedData: [String: AnyObject], resource: Resource) {
		for (attributeName, attribute) in resource.persistentAttributes {
			if attribute.isRelationship() {
				continue
			}
			
			let key = attribute.representationName ?? attributeName
			
			if let unformattedValue: AnyObject = resource.valueForKey(attributeName) {
				self.addAttribute(&serializedData, key: key, value: self.formatter.serialize(unformattedValue, ofType: attribute.type))
			} else {
				self.addAttribute(&serializedData, key: key, value: NSNull())
			}
		}
	}
	
	/**
	Adds the given key/value pair to the passed serialized data.
	
	:param: serializedData The data to add the key/value pair to.
	:param: key            The key to add to the serialized data.
	:param: value          The value to add to the serialized data.
	*/
	private func addAttribute(inout serializedData: [String: AnyObject], key: String, value: AnyObject) {
		serializedData[key] = value
	}
	
	// MARK: Relationships
	
	/**
	Adds the relationships of the the given resource to the passed serialized data.
	
	This method loops over all the relationships in the passed resource, maps the attribute name
	to the key for the serialized form and gets the related attributes It then passes the key and
	related resources to either the addToOneRelationship or addToManyRelationship method.
	
	
	:param: serializedData The data to add the relationships to.
	:param: resource       The resource whose relationships to add.
	*/
	private func addRelationships(inout serializedData: [String: AnyObject], resource: Resource) {
		for (attributeName, attribute) in resource.persistentAttributes {
			if !attribute.isRelationship() {
				continue
			}
			
			let key = attribute.representationName ?? attributeName

			switch attribute.type {
				case .ToOne:
					self.addToOneRelationship(&serializedData, key: key, relatedResource: resource.valueForKey(attributeName) as? Resource)
				case .ToMany:
					self.addToManyRelationship(&serializedData, key: key, relatedResources: resource.valueForKey(attributeName) as? [Resource])
				default: ()
			}
		}
	}
	
	/**
	Adds the given resource as a to to-one relationship to the serialized data.
	
	:param: serializedData  The data to add the related resource to.
	:param: key             The key to add to the serialized data.
	:param: relatedResource The related resource to add to the serialized data.
	*/
	private func addToOneRelationship(inout serializedData: [String: AnyObject], key: String, relatedResource: Resource?) {
		var linkData: AnyObject
		
		if let ID = relatedResource?.resourceID {
			linkData = ID
		} else {
			linkData = NSNull()
		}
		
		if serializedData["links"] == nil {
			serializedData["links"] = [key: linkData]
		} else {
			var links: [String: AnyObject] = serializedData["links"]! as [String: AnyObject]
			links[key] = linkData
			serializedData["links"] = links
		}
	}
	
	/**
	Adds the given resources as a to to-many relationship to the serialized data.
	
	:param: serializedData   The data to add the related resources to.
	:param: key              The key to add to the serialized data.
	:param: relatedResources The related resources to add to the serialized data.
	*/
	private func addToManyRelationship(inout serializedData: [String: AnyObject], key: String, relatedResources: [Resource]?) {
		var linkData: AnyObject
		
		if let resources = relatedResources {
			let IDs: [String] = resources.filter { resource in
				return resource.resourceID != nil
			}.map { resource in
				return resource.resourceID!
			}
			
			linkData = IDs
			
		} else {
			linkData = []
		}
		
		if serializedData["links"] == nil {
			serializedData["links"] = [key: linkData]
		} else {
			var links: [String: AnyObject] = serializedData["links"]! as [String: AnyObject]
			links[key] = linkData
			serializedData["links"] = links
		}
	}
}


// MARK:

class Formatter {

	private func deserialize(value: AnyObject, ofType type: ResourceAttribute.AttributeType) -> AnyObject {
		switch type {
		case .Date:
			return self.deserializeDate(value as String)
		default:
			return value
		}
	}
	
	private func serialize(value: AnyObject, ofType type: ResourceAttribute.AttributeType) -> AnyObject {
		switch type {
		case .Date:
			return self.serializeDate(value as NSDate)
		default:
			return value
		}
	}
	
	// MARK: Date
	
	private lazy var dateFormatter: NSDateFormatter = {
		let formatter = NSDateFormatter()
		formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
		return formatter
	}()

	private func serializeDate(date: NSDate) -> String {
		return self.dateFormatter.stringFromDate(date)
	}

	private func deserializeDate(value: String) -> NSDate {
		if let date = self.dateFormatter.dateFromString(value) {
			return date
		}
		
		return NSDate()
	}
}