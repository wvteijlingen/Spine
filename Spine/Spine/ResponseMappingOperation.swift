//
//  ResponseMappingOperation.swift
//  Spine
//
//  Created by Ward van Teijlingen on 30-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation
import SwiftyJSON

class ResponseMappingOperation: NSOperation {
	
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