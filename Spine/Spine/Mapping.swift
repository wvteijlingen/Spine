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

public class Mapper {
	
	var registeredClasses: [String: Resource.Type] = [:]
	
	public func registerType(type: Resource.Type, resourceType: String) {
		self.registeredClasses[resourceType] = type
	}
	
	public func classNameForResourceType(resourceType: String) -> Resource.Type {
		return self.registeredClasses[resourceType]!
	}

	func mapResponseData(data: JSONValue) -> ResourceStore {
		let mappingOperation = ResponseMappingOperation(responseData: data, mapper: self)
		mappingOperation.start()
		return mappingOperation.mappingResult!
	}

	func mapResponseData(data: JSONValue, usingStore store: ResourceStore) -> ResourceStore {
		let mappingOperation = ResponseMappingOperation(responseData: data, store: store, mapper: self)
		mappingOperation.start()
		return mappingOperation.mappingResult!
	}

	func mapResourcesToDictionary(resources: [Resource]) -> [String: [ResourceRepresentation]] {
		let mappingOperation = RequestMappingOperation(resources: resources)
		mappingOperation.start()
		return mappingOperation.mappingResult!
	}
}


// MARK: -

class ResponseMappingOperation: NSOperation {
	
	private var responseData: JSONValue
	private var store: ResourceStore
	private var mapper: Mapper
	
	private lazy var formatter = {
		Formatter()
	}()
	
	var mappingResult: ResourceStore?
	
	init(responseData: JSONValue, mapper: Mapper) {
		self.responseData = responseData
		self.mapper = mapper
		self.store = ResourceStore()
		super.init()
	}
	
	init(responseData: JSONValue, store: ResourceStore, mapper: Mapper) {
		self.responseData = responseData
		self.mapper = mapper
		self.store = store
		super.init()
	}
	
	override func main() {
		assert(self.responseData.object != nil, "The given JSON representation was not of type 'object' (dictionary).")
		
		for(resourceType: String, resourcesData: JSONValue) in self.responseData.object! {
			if resourceType == "linked" {
				for (linkedResourceType, linkedResources) in resourcesData.object! {
					for representation in linkedResources.array! {
						self.mapSingleRepresentation(representation, withResourceType: linkedResourceType)
					}
				}
			} else if let resources = resourcesData.array {
				for representation in resources {
					self.mapSingleRepresentation(representation, withResourceType: resourceType)
				}
			}
		}
		
		self.resolveRelations()
		
		self.mappingResult = self.store
	}

	/**
	Maps a single resource representation into a resource object of the given type.
	
	:param: representation The JSON representation of a single resource.
	:param: resourceType   The type of resource onto which to map the representation.
	*/
	private func mapSingleRepresentation(representation: JSONValue, withResourceType resourceType: String) {
		if let existingResource = self.store.resource(resourceType, identifier: representation["id"].string!) {
			self.mapJSONRepresentation(representation, intoResource: existingResource)
		} else {
			let resource: Resource = self.mapper.classNameForResourceType(resourceType)() as Resource
			self.mapJSONRepresentation(representation, intoResource: resource)
			self.store.add(resource)
		}
	}
	
	/**
	Maps the given JSON representation into the given resource object.
	
	:param: representation JSON representation to map. This must be JSONValue of case 'object'.
	:param: resource       The resource object into which to map the representation.
	*/
	private func mapJSONRepresentation(representation: JSONValue, intoResource resource: Resource) {
		assert(representation.object != nil, "The given JSON representation was not of type 'object' (dictionary).")
		
		let attributes = resource.persistentAttributes
		
		for (key, value) in representation.object! {
			if key == "links" {
				if let links = value.object {
					for (linkName, linkData) in links {
						if let id = linkData["id"].string {
							let relationship = ResourceRelationship.ToOne(href: linkData["href"].string!, ID: id, type: linkData["type"].string!)
							resource.relationships[linkName] = relationship
						}
						
						if let ids = linkData["ids"].array {
							let stringIDs: [String] = ids.map({ value in
								return value.string!
							})
							let relationship = ResourceRelationship.ToMany(href: linkData["href"].string!, IDs: stringIDs, type: linkData["type"].string!)
							resource.relationships[linkName] = relationship
						}
					}
				}
				
			} else if key == "id" {
				resource.resourceID = value.string
			} else if key == "href" {
				resource.resourceLocation = value.string
			} else {
				if let attribute = attributes[key] {
					switch attribute {
					case .Date:
						resource.setValue(self.formatter.extractDate(value.string!), forKey: key)
					default:
						resource.setValue(value.any, forKey: key)
					}
				} else {
					resource.setValue(value.any, forKey: key)
				}
			}
		}
	}
	
	/**
	Resolves the relations of the given resource by looking up related target resources in the store.
	
	:param: resources Array of resources for which to resolve the relations.
	:param: store     Resource store in which to look up related target resources.
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
						let placeholderResource = self.mapper.classNameForResourceType(type)() as Resource
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
							let placeholderResource = self.mapper.classNameForResourceType(type)() as Resource
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

class RequestMappingOperation: NSOperation {
	
	private let resources: [Resource]
	private let formatter = Formatter()
	
	var mappingResult: [String: [ResourceRepresentation]]?
	
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
				switch attribute {
				case .Property:
					properties[attributeName] = resource.valueForKey(attributeName)
					
				case .Date:
					properties[attributeName] = self.formatter.formatDate(resource.valueForKey(attributeName) as NSDate)
					
				case .ToOne:
					if let relatedResource = resource.valueForKey(attributeName) as? Resource {
						links[attributeName] = relatedResource.resourceID
					} else {
						links[attributeName] = NSNull()
					}
					
				case .ToMany:
					if let relatedResources = resource.valueForKey(attributeName) as? [Resource] {
						let IDs: [String] = relatedResources.map { (resource) in
							assert(resource.resourceID != nil, "Related resources must be saved before saving their parent resource.")
							return resource.resourceID!
						}
						links[attributeName] = IDs
					} else {
						links[attributeName] = []
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
		
		self.mappingResult = dictionary
	}
}

// MARK: - Formatters
class Formatter {

	private lazy var dateFormatter: NSDateFormatter = {
		let formatter = NSDateFormatter()
		formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
		return formatter
	}()

	func formatDate(date: NSDate) -> String {
		return self.dateFormatter.stringFromDate(date)
	}

	func extractDate(value: String) -> NSDate {
		if let date = self.dateFormatter.dateFromString(value) {
			return date
		}
		
		return NSDate()
	}
}