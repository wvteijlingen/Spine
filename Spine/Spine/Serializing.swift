//
//  Mapping.swift
//  Spine
//
//  Created by Ward van Teijlingen on 23-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation
import SwiftyJSON

typealias ResourceRepresentation = [String: AnyObject]

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

	func deserializeData(data: JSONValue) -> ResourceStore {
		let mappingOperation = DeserializeOperation(data: data, classMap: self.classMap)
		mappingOperation.start()
		return mappingOperation.result!
	}

	func deserializeData(data: JSONValue, usingStore store: ResourceStore) -> ResourceStore {
		let mappingOperation = DeserializeOperation(data: data, store: store, classMap: self.classMap)
		mappingOperation.start()
		return mappingOperation.result!
	}
	
	func deserializeError(data: JSONValue, withResonseStatus responseStatus: Int) -> NSError {
		let code = data["errors"][0]["id"].integer ?? responseStatus
		
		var userInfo: [String : AnyObject]?
		
		if let errorTitle = data["errors"][0]["title"].string {
			userInfo = [NSLocalizedDescriptionKey: errorTitle]
		}
		
		return NSError(domain: SPINE_ERROR_DOMAIN, code: code, userInfo: userInfo)
	}

	func serializeResources(resources: [Resource]) -> [String: [ResourceRepresentation]] {
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
	
	init(data: JSONValue, classMap: ResourceClassMap) {
		self.data = data
		self.classMap = classMap
		self.store = ResourceStore()
		super.init()
	}
	
	init(data: JSONValue, store: ResourceStore, classMap: ResourceClassMap) {
		self.data = data
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
					resource.setValue(self.formatter.unformatValue(value, ofType: attribute), forKey: attributeName)
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
	
	var result: [String: [ResourceRepresentation]]?
	
	init(resources: [Resource]) {
		self.resources = resources
	}
	
	override func main() {
		var dictionary: [String: [ResourceRepresentation]] = [:]
		
		//Loop through all resources
		for resource in resources {
			var properties: ResourceRepresentation = [:]
			var links: [String: AnyObject] = [:]
			
			// Special attributes
			if let ID = resource.resourceID {
				properties["id"] = ID
			}
			
			//Add the other persistent attributes to the representation
			for (attributeName, attribute) in resource.persistentAttributes {
				let targetKey = attribute.representationName ?? attributeName
				
				switch attribute.type {
				case .Property:
					properties[targetKey] = resource.valueForKey(attributeName)
					
				case .Date:
					properties[targetKey] = self.formatter.formatDate(resource.valueForKey(attributeName) as NSDate)
					
				case .ToOne:
					if let relatedResource = resource.valueForKey(attributeName) as? Resource {
						links[targetKey] = relatedResource.resourceID
					} else {
						links[targetKey] = NSNull()
					}
					
				case .ToMany:
					if let relatedResources = resource.valueForKey(attributeName) as? [Resource] {
						let IDs: [String] = relatedResources.map { (resource) in
							assert(resource.resourceID != nil, "Related resources must be saved before saving their parent resource.")
							return resource.resourceID!
						}
						links[targetKey] = IDs
					} else {
						links[targetKey] = []
					}
				}
			}
			
			//If links were found, add them to the representation
			if links.count != 0 {
				properties["links"] = links
			}
			
			//Add the resource representation to the root dictionary
			if dictionary[resource.resourceType] == nil {
				dictionary[resource.resourceType] = [properties]
			} else {
				dictionary[resource.resourceType]!.append(properties)
			}
		}
		
		self.result = dictionary
	}
}


// MARK:

class Formatter {

	private func unformatValue(value: AnyObject, ofType type: ResourceAttribute) -> AnyObject {
		switch type.type {
		case .Date:
			return self.unformatDate(value as String)
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

	private func formatDate(date: NSDate) -> String {
		return self.dateFormatter.stringFromDate(date)
	}

	private func unformatDate(value: String) -> NSDate {
		if let date = self.dateFormatter.dateFromString(value) {
			return date
		}
		
		return NSDate()
	}
}