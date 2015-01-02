//
//  DeserializeOperation.swift
//  Spine
//
//  Created by Ward van Teijlingen on 30-12-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation
import SwiftyJSON

/**
*  A DeserializeOperation is responsible for deserializing a single server response.
*  The serialized data is converted into Resource instances using a layered process.
*
*  This process is the inverse of that of the SerializeOperation.
*/
class DeserializeOperation: NSOperation {
	
	// Input
	private let classMap: ResourceClassMap
	private let transformers: TransformerDirectory = TransformerDirectory()
	private let data: JSON
	private let options: DeserializationOptions
	
	// Output
	private var store: Store
	private var paginationData: PaginationData?
	
	var result: DeserializationResult?
	
	init(data: NSData, classMap: ResourceClassMap, options: DeserializationOptions) {
		self.data = JSON(data: data)
		self.classMap = classMap
		self.options = options
		self.store = Store()
		super.init()
	}
	
	init(data: NSData, store: Store, classMap: ResourceClassMap, options: DeserializationOptions) {
		self.data = JSON(data: data)
		self.classMap = classMap
		self.options = options
		self.store = store
		super.init()
	}
	
	override func main() {
		// Check if the given data is in the expected format
		if (self.data.dictionary == nil) {
			let error = NSError(domain: SPINE_ERROR_DOMAIN, code: 0, userInfo: [NSLocalizedDescriptionKey: "The given JSON representation was not as expected."])
			self.result = DeserializationResult(nil, nil, error)
			return
		}
		
		// Extract link templates
		let linkTemplates: JSON? = self.data.dictionaryValue["links"]
		
		// Extract resources
		for(key: String, data: JSON) in self.data.dictionaryValue {
			// Linked resources for compound documents
			if key == "linked" {
				for (linkedResourceType, linkedResources) in data.dictionaryValue {
					for representation in linkedResources.array! {
						self.deserializeSingleRepresentation(representation, withResourceType: linkedResourceType, linkTemplates: linkTemplates)
					}
				}
				
			} else if key != "links" && key != "meta" {
				// Multiple resources
				if let representations = data.array {
					for representation in representations {
						self.deserializeSingleRepresentation(representation, withResourceType: key, linkTemplates: linkTemplates)
					}
					
					// Single resource
				} else {
					self.deserializeSingleRepresentation(data, withResourceType: key, linkTemplates: linkTemplates)
				}
			}
		}
		
		// Extract meta
		self.extractMeta()
		
		// Resolve relations in the store
		self.resolveRelations()
		
		// Create a result
		self.result = DeserializationResult(self.store, self.paginationData, nil)
	}
	
	/**
	Maps a single resource representation into a resource object of the given type.
	
	:param: representation The JSON representation of a single resource.
	:param: resourceType   The type of resource onto which to map the representation.
	*/
	private func deserializeSingleRepresentation(representation: JSON, withResourceType resourceType: String, linkTemplates: JSON? = nil) {
		assert(representation.dictionary != nil, "The given JSON representation was not of type 'object' (dictionary).")
		
		// Find existing resource in the store, or create a new resource.
		let resource: Resource = dispenseResourceWithType(resourceType, id: representation["id"].stringValue, useFirst: options.mapOntoFirstResourceInStore)
		
		// Extract data into resource
		self.extractID(representation, intoResource: resource)
		self.extractHref(representation, intoResource: resource)
		self.extractAttributes(representation, intoResource: resource)
		self.extractRelationships(representation, intoResource: resource, linkTemplates: linkTemplates)
		
		// Set loaded flag
		resource.isLoaded = true
	}
	
	private func dispenseResourceWithType(type: String, id: String, useFirst: Bool) -> Resource {
		var resource: Resource
		var isExistingResource: Bool
		
		if let existingResource = store.objectWithType(type, identifier: id) {
			resource = existingResource
			isExistingResource = true
			
		} else if useFirst {
			if let existingResource = store.allObjectsWithType(type).first {
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
			store.add(resource)
		}
		
		return resource
	}
	
	
	// MARK: Special attributes
	
	/**
	Extracts the resource ID from the serialized data into the given resource.
	
	:param: serializedData The data from which to extract the ID.
	:param: resource       The resource into which to extract the ID.
	*/
	private func extractID(serializedData: JSON, intoResource resource: Resource) {
		if serializedData["id"].stringValue != "" {
			resource.id = serializedData["id"].stringValue
		} else {
			assertionFailure("Cannot deserialize resource of type: \(resource.dynamicType.type). Serializated data must contain a primary key named 'id'.")
		}
	}
	
	/**
	Extracts the resource href from the serialized data into the given resource.
	
	:param: serializedData The data from which to extract the href.
	:param: resource       The resource into which to extract the href.
	*/
	private func extractHref(serializedData: JSON, intoResource resource: Resource) {
		if let href = serializedData["href"].URL {
			resource.href = href
		}
	}
	
	
	// MARK: Attributes
	
	/**
	Extracts the attributes from the given data into the given resource.
	
	This method loops over all the attributes in the passed resource, maps the attribute name
	to the key for the serialized form and invokes `extractAttribute`. It then formats the extracted
	attribute and sets the formatted value on the resource.
	
	:param: serializedData The data from which to extract the attributes.
	:param: resource       The resource into which to extract the attributes.
	*/
	private func extractAttributes(serializedData: JSON, intoResource resource: Resource) {
		for attribute in resource.attributes {
			if isRelationship(attribute) {
				continue
			}
			
			let key = attribute.serializedName
			
			if let extractedValue: AnyObject = self.extractAttribute(serializedData, key: key) {
				let formattedValue: AnyObject = self.transformers.deserialize(extractedValue, forAttribute: attribute)
				resource.setValue(formattedValue, forKey: attribute.name)
			}
		}
	}
	
	/**
	Extracts the value for the given key from the passed serialized data.
	
	:param: serializedData The data from which to extract the attribute.
	:param: key            The key for which to extract the value from the data.
	
	:returns: The extracted value or nil if no attribute with the given key was found in the data.
	*/
	private func extractAttribute(serializedData: JSON, key: String) -> AnyObject? {
		let value = serializedData[key]
		
		if let nullValue = value.null {
			return nil
		} else {
			return value.rawValue
		}
	}
	
	
	// MARK: Relationships
	
	/**
	Extracts the relationships from the given data into the given resource.
	
	This method loops over all the relationships in the passed resource, maps the relationship name
	to the key for the serialized form and invokes `extractToOneRelationship` or `extractToManyRelationship`.
	It then sets the extracted ResourceRelationship on the resource.
	
	:param: serializedData The data from which to extract the relationships.
	:param: resource       The resource into which to extract the relationships.
	*/
	private func extractRelationships(serializedData: JSON, intoResource resource: Resource, linkTemplates: JSON? = nil) {
		for attribute in resource.attributes {
			if !isRelationship(attribute) {
				continue
			}
			
			let key = attribute.serializedName
			
			switch attribute {
			case let toOne as ToOneAttribute:
				if let linkedResource = self.extractToOneRelationship(serializedData, key: key, linkedType: toOne.linkedType, resource: resource, linkTemplates: linkTemplates) {
					resource.setValue(linkedResource, forKey: attribute.name)
				}
			case let toMany as ToManyAttribute:
				if let linkedResources = self.extractToManyRelationship(serializedData, key: key, linkedType: toMany.linkedType, resource: resource, linkTemplates: linkTemplates) {
					resource.setValue(linkedResources, forKey: attribute.name)
				}
			default: ()
			}
		}
	}
	
	/**
	Extracts the to-one relationship for the given key from the passed serialized data.
	
	This method supports both the single ID form and the resource object forms.
	
	:param: serializedData The data from which to extract the relationship.
	:param: key            The key for which to extract the relationship from the data.
	
	:returns: The extracted relationship or nil if no relationship with the given key was found in the data.
	*/
	private func extractToOneRelationship(serializedData: JSON, key: String, linkedType: String, resource: Resource, linkTemplates: JSON? = nil) -> Resource? {
		func extractedResource(type: String, id: String?, href: NSURL?) -> Resource {
			// If no ID is given, we cannot add it to the store. Return a placeholder resource.
			if id == nil {
				let resource = self.classMap[type]() as Resource
				resource.id = id
				return resource
			}
			
			let resource = self.dispenseResourceWithType(type, id: id!, useFirst: false)
			resource.href = href
			return resource
		}
		
		// Resource level link with href/id/type combo
		if let linkData = serializedData["links"][key].dictionary {
			var href: NSURL?, type: String, ID: String?
			
			if let rawHref = linkData["href"]?.string {
				href = NSURL(string: rawHref)
			}
			
			if let rawType = linkData["type"]?.string {
				type = rawType
			} else {
				type = linkedType
			}
			
			if linkData["id"]?.stringValue != "" {
				ID = linkData["id"]!.stringValue
			}
			
			return extractedResource(type, ID, href)
		}
		
		// Resource level link with only an id
		let ID = serializedData["links"][key].stringValue
		if ID != "" {
			return extractedResource(linkedType, ID, nil)
		}
		
		// Document level link template
		if let linkData = linkTemplates?[resource.dynamicType.type + "." + key].dictionary {
			var href: NSURL?, type: String
			
			if let hrefTemplate = linkData["href"]?.string {
				if let interpolatedHref = hrefTemplate.interpolate(serializedData.dictionaryObject! as NSDictionary, rootKeyPath: resource.dynamicType.type) {
					href = NSURL(string: interpolatedHref)
				} else {
					assertionFailure("Could not interpolate href template: \(hrefTemplate) with values: \(serializedData.dictionaryObject!).")
				}
			}
			
			if let rawType = linkData["type"]?.string {
				type = rawType
			} else {
				type = linkedType
			}
			
			return extractedResource(type, nil, href)
		}
		
		return nil
	}
	
	/**
	Extracts the to-many relationship for the given key from the passed serialized data.
	
	This method supports both the array of IDs form and the resource object forms.
	
	:param: serializedData The data from which to extract the relationship.
	:param: key            The key for which to extract the relationship from the data.
	
	:returns: The extracted relationship or nil if no relationship with the given key was found in the data.
	*/
	private func extractToManyRelationship(serializedData: JSON, key: String, linkedType: String, resource: Resource, linkTemplates: JSON? = nil) -> ResourceCollection? {
		// Resource level link with href/id/type combo
		if let linkData = serializedData["links"][key].dictionary {
			var href: NSURL?, type: String, IDs: [String]?
			
			if let rawHref = linkData["href"]?.string {
				href = NSURL(string: rawHref)
			}
			
			if let rawIDs = linkData["ids"]?.array {
				IDs = rawIDs.map { $0.stringValue }
				IDs?.filter { $0 != "" }
			}
			
			if let rawType = linkData["type"]?.string {
				type = rawType
			} else {
				type = linkedType
			}
			
			return ResourceCollection(href: href, type: type, ids: IDs)
		}
		
		// Resource level link with only ids
		if let rawIDs: [JSON] = serializedData["links"][key].array {
			let IDs = rawIDs.map { $0.stringValue }
			IDs.filter { return $0 != "" }
			return ResourceCollection(href: nil, type: linkedType, ids: IDs)
		}
		
		// Document level link template
		if let linkData = linkTemplates?[resource.dynamicType.type + "." + key].dictionary {
			var href: NSURL?, type: String, IDs: [String]?
			
			if let hrefTemplate = linkData["href"]?.string {
				if let interpolatedHref = hrefTemplate.interpolate(serializedData.dictionaryObject! as NSDictionary, rootKeyPath: resource.dynamicType.type) {
					href = NSURL(string: interpolatedHref)
				} else {
					assertionFailure("Error: Could not interpolate href template: \(hrefTemplate) with values \(serializedData.dictionaryObject!).")
				}
			}
			
			if let rawType = linkData["type"]?.string {
				type = rawType
			} else {
				type = linkedType
			}
			
			if let rawIDs = serializedData["links"][key].array {
				IDs = rawIDs.map { return $0.stringValue }
				IDs?.filter { return $0 != "" }
			}
			
			return ResourceCollection(href: href, type: type, ids: IDs)
		}
		
		return nil
	}
	
	/**
	Resolves the relations of the resources in the store.
	*/
	private func resolveRelations() {
		for resource in self.store {
			
			for attribute in resource.attributes {
				if !isRelationship(attribute) {
					continue
				}
				
				switch attribute {
				case let toMany as ToManyAttribute:
					if let linkedResource = resource.valueForKey(attribute.name) as? ResourceCollection {
						var targetResources: [Resource] = []
						
						// We can only resolve if IDs are known
						if let ids = linkedResource.ids {
							
							for id in ids {
								// Find target of relation in store
								if let targetResource = store.objectWithType(linkedResource.type, identifier: id) {
									targetResources.append(targetResource)
								} else {
									println("Cannot resolve to-many link \(resource.dynamicType.type):\(resource.id!) - \(attribute.name) -> \(linkedResource.type):\(id) because the linked resource does not exist in the store.")
								}
							}
							
							linkedResource.fulfill(targetResources)
						} else {
							println("Cannot resolve to-many link \(resource.dynamicType.type):\(resource.id!) - \(attribute.name) -> \(linkedResource.type):? because the foreign IDs are not known.")
						}
					} else {
						println("Cannot resolve to-many link \(resource.dynamicType.type):\(resource.id!) - \(attribute.name) -> ? because the link data is not fetched.")
					}
					
				default: ()
				}
			}
		}
	}
	
	
	// MARK: Meta
	
	private func extractMeta() {
		if let meta = self.data["meta"].dictionary {
			var paginationData = PaginationData(
				count: meta["count"]?.int,
				limit: meta["limit"]?.int,
				beforeCursor: meta["before_cursor"]?.string,
				afterCursor: meta["after_cursor"]?.string,
				nextHref: nil,
				previousHref: nil
			)
			
			if let nextHref = meta["after_cursor"]?.string {
				paginationData.nextHref = NSURL(string: nextHref)
			}
			
			if let previousHref = meta["previous_cursor"]?.string {
				paginationData.previousHref = NSURL(string: previousHref)
			}
			
			self.paginationData = paginationData
		}
	}
}