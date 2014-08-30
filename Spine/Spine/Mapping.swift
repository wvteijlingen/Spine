//
//  Mapping.swift
//  Spine
//
//  Created by Ward van Teijlingen on 23-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation
import SwiftyJSON

public class Mapper {
	
	var registeredClasses: [String: Resource.Type] = [:]
	
	
	// MARK: Custom classes
	
	public func registerType(type: Resource.Type, resourceType: String) {
		self.registeredClasses[resourceType] = type
	}
	
	public func classNameForResourceType(resourceType: String) -> Resource.Type {
		return self.registeredClasses[resourceType]!
	}

	
	// MARK: Response mapping
	
	/**
	Maps the response data into a resource store.
	
	:param: data The JSON data to map.
	
	:returns: The resource store containing the populated resources.
	*/
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


	// MARK: Request mapping

	func mapResourcesToDictionary(resources: [Resource]) -> [String: [NSMutableDictionary]] {
		var dictionary: [String: [NSMutableDictionary]] = [:]
		
		//Loop through all resources
		for resource in resources {
			
			//Create a root resource key in the mapped dictionary
			let resourceType = resource.resourceType
			if dictionary[resourceType] == nil {
				dictionary[resourceType] = []
			}
			
			var values: NSMutableDictionary = NSMutableDictionary()
			var links: NSMutableDictionary = NSMutableDictionary()
			
			//Add the ID to the representation
			if let ID = resource.resourceID {
				values.setValue(ID, forKey: "id")
			}
			
			for (attributeName, attribute) in resource.persistentAttributes {
				switch attribute {
				
				//The attribute is a plain property, add it to the representation
				case .Property:
					values.setValue(resource.valueForKey(attributeName), forKey: attributeName)

				//The attribute is a date, format it as ISO-8601
				case .Date:
					let formatter = NSDateFormatter()
					formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
					values.setValue(formatter.stringFromDate(resource.valueForKey(attributeName) as NSDate), forKey: attributeName)
					
				//The attribute is a to-one relationship, add related ID, or null if no resource is related
				case .ToOne:
					if let relatedResource = resource.valueForKey(attributeName) as? Resource {
						links.setValue(relatedResource.resourceID, forKey: attributeName)
					} else {
						links.setValue(NSNull(), forKey: attributeName)
					}
					
				//The attribute is a to-many relationship, add related IDs, or an empty array if no resources are related
				case .ToMany:
					if let relatedResources = resource.valueForKey(attributeName) as? [Resource] {
						let IDs: [String] = relatedResources.map { (resource) in
							assert(resource.resourceID != nil, "Related resources must be saved before saving their parent resource.")
							return resource.resourceID!
						}
						links.setValue(IDs, forKey: attributeName)
					} else {
						links.setValue([], forKey: attributeName)
					}
				}
			}
			
			//If links were found, add them to the representation
			if links.allKeys.count != 0 {
				values.setValue(links, forKey: "links")
			}
			
			//Add the resoruce respresentation to the root dictionary
			dictionary[resourceType]!.append(values)
		}
		
		return dictionary
	}
}

private class ResponseMappingOperation: NSOperation {

	private var responseData: JSONValue
	private var store: ResourceStore
	private var mapper: Mapper
	private var linkTemplates: [String: JSONValue] = [:]

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
		// This function creates a new resource object if needed, and calls the mapping function to map the data into it
		let mapFunction: (JSONValue, String) -> Void = { (data, resourceType) in
			if let existingResource = self.store.resource(resourceType, identifier: data["id"].string!) {
				self.mapJSONRepresentation(data, intoResource: existingResource)
			} else {
				let resource: Resource = self.mapper.classNameForResourceType(resourceType)() as Resource
				self.mapJSONRepresentation(data, intoResource: resource)
				self.store.add(resource)
			}
		}

		// Extract link templates
		if let linkTemplates = self.responseData["links"].object {
			for linkTemplateName in linkTemplates {
				
			}
		}
		
		assert(self.responseData.object != nil, "The given JSON representation was not of type 'object' (dictionary).")

		// Create objects for resources
		for(resourceType: String, resourcesData: JSONValue) in self.responseData.object! {
			if resourceType == "linked" {
				for (linkedResourceType, linkedResources) in resourcesData.object! {
					for rawObject in linkedResources.array! {
						mapFunction(rawObject, linkedResourceType)
					}
				}
			} else if let resources = resourcesData.array {
				for rawObject in resources {
					mapFunction(rawObject, resourceType)
				}
			}
		}

		self.resolveRelations()

		self.mappingResult = self.store
	}

	/**
	 Maps the given JSON representation into the given resource object.

	 :param: representation JSON representation to map. This must be JSONValue of case 'object'.
	 :param: resource       The resource object into which to map the representation.
	 */
	func mapJSONRepresentation(representation: JSONValue, intoResource resource: Resource) {
		assert(representation.object != nil, "The given JSON representation was not of type 'object' (dictionary).")

		let attributes = resource.persistentAttributes

		for (key, value) in representation.object! {
			if key == "links" {
				if let links = value.object {
					for (linkName, linkData) in links {
						if let id = linkData["id"].string {
							let relationship = ResourceRelation.ToOne(href: linkData["href"].string!, ID: id, type: linkData["type"].string!)
							resource.relationships[linkName] = relationship
						}

						if let ids = linkData["ids"].array {
							let stringIDs: [String] = ids.map({ value in
								return value.string!
							})
							let relationship = ResourceRelation.ToMany(href: linkData["href"].string!, IDs: stringIDs, type: linkData["type"].string!)
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
							let formatter = NSDateFormatter()
							formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
							if let date = formatter.dateFromString(value.string!) {
								resource.setValue(date, forKey: key)
							}
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
	 Resolves the relations of the given resource by looking up related target resources in the given store.

	 :param: resources Array of resources for which to resolve the relations.
	 :param: store     Resource store in which to look up related target resources.
	 */
	private func resolveRelations() {
		for resource in self.store.allResources() {

			for (relationshipName: String, relation: ResourceRelation) in resource.relationships {

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

//MARK: -

class ResourceStore: Printable {
	var resources: [String : [String: Resource]] = [:]
	
	func add(resource: Resource) {
		assert(resource.resourceID != nil, "ResourceStore can only store resources with a resourceID.")

		let resourceType = resource.resourceType
		if (self.resources[resourceType] == nil) {
			self.resources[resourceType] = [:]
		}
		self.resources[resourceType]![resource.resourceID!] = resource
	}
	
	func remove(resource: Resource) {
		assert(resource.resourceID != nil, "ResourceStore can only store resources with a resourceID.")

		if self.resources[resource.resourceType] != nil {
			self.resources[resource.resourceType]![resource.resourceID!] = nil
		}
	}
	
	func resource(resourceType: String, identifier: String) -> Resource? {
		if let resources = self.resources[resourceType] {
			if let resource = resources[identifier] {
				return resource
			}
		}
		
		return nil
	}
	
	func containsResourceWithType(resourceType: String, identifier: String) -> Bool {
		if let resources = self.resources[resourceType] {
			if let resource = resources[identifier] {
				return true
			}
		}
		
		return false
	}
	
	func resourcesWithName(resourceType: String) -> [Resource]? {
		var resources: [Resource] = []
		
		if let resourcesByID: [String: Resource] = self.resources[resourceType] {
			for value in resourcesByID.values {
				resources.append(value)
			}
			
			return resources
		}
		
		return nil
	}

	func allResources() -> [Resource] {
		var resources: [Resource] = []

		for (resourceType, resourcesByID) in self.resources {
			resources += resourcesByID.values
		}

		return resources
	}

	var description: String {
		var string = ""
		for (resourceType, resources) in self.resources {
			for (resourceID, resource) in resources {
				string += "\(resourceType)[\(resourceID)]\n"
			}
		}

		return string
	}
}