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
	let data: JSON
	var transformers: TransformerDirectory = TransformerDirectory()
	var resourceFactory: ResourceFactory
	
	// Output
	var result: DeserializationResult?
	
	// Private
	private var resources: [ResourceProtocol] = []
	private var paginationData: PaginationData?
	
	init(data: NSData, resourceFactory: ResourceFactory) {
		self.data = JSON(data: data)
		self.resourceFactory = resourceFactory
	}
	
	func addMappingTargets(targets: [ResourceProtocol]) {
		// We can only map onto resources that are not loaded yet
		for resource in targets {
			assert(resource.isLoaded == false, "Cannot map onto loaded resource \(resource)")
		}
		
		resources += targets
	}
	
	override func main() {
		// Check if the given data is in the expected format
		if (data.dictionary == nil) {
			result = .Failure(NSError(domain: SPINE_ERROR_DOMAIN, code: 0, userInfo: [NSLocalizedDescriptionKey: "The given JSON representation was not as expected."]))
			return
		}
		
		// Extract link templates
		let linkTemplates: JSON? = self.data.dictionaryValue["links"]
		
		// Extract main resources
		if let data = self.data["data"].array {
			for representation in data {
				deserializeSingleRepresentation(representation, linkTemplates: linkTemplates)
			}
		} else if let data = self.data["data"].dictionary {
			deserializeSingleRepresentation(self.data["data"], linkTemplates: linkTemplates)
		}
		
		// Extract linked resources
		if let data = self.data["linked"].array {
			for representation in data {
				deserializeSingleRepresentation(representation, linkTemplates: linkTemplates)
			}
		}
		
		// Extract meta
		extractMeta()
		
		// Resolve relations in the store
		resolveRelations()
		
		// Create a result
		result = .Success(resources: resources, pagination: paginationData)
	}

	/**
	Maps a single resource representation into a resource object of the given type.
	
	:param: representation The JSON representation of a single resource.
	:param: resourceType   The type of resource onto which to map the representation.
	*/
	private func deserializeSingleRepresentation(representation: JSON, linkTemplates: JSON? = nil) {
		assert(representation.dictionary != nil, "The given JSON representation was not of type 'object' (dictionary).")
		assert(representation["type"].string != nil, "The given JSON representation did not have a type.")
		
		// Dispense a resource
		let resource = resourceFactory.dispense(representation["type"].string!, id: representation["id"].stringValue, pool: &resources)
		
		// Extract ID
		resource.id = representation["id"].stringValue
		assert(resource.id != "", "Cannot deserialize resource of type: \(resource.type). Serializated data must contain a primary key named 'id' which must be non-empty.")
		
		// Extract href
		resource.URL = representation["links"]["self"].URL

		// Extract data
		extractAttributes(representation, intoResource: resource)
		extractRelationships(representation, intoResource: resource, linkTemplates: linkTemplates)
		
		// Set loaded flag
		resource.isLoaded = true
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
	private func extractAttributes(serializedData: JSON, intoResource resource: ResourceProtocol) {
		for attribute in resource.attributes.filter({ $0 is RelationshipAttribute == false }) {
			if let extractedValue: AnyObject = extractAttribute(serializedData, key: attribute.serializedName) {
				let formattedValue: AnyObject = transformers.deserialize(extractedValue, forAttribute: attribute)
				resource.setValue(formattedValue, forAttribute: attribute.name)
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
	private func extractRelationships(serializedData: JSON, intoResource resource: ResourceProtocol, linkTemplates: JSON? = nil) {
		for attribute in resource.attributes {
			switch attribute {
			case let toOne as ToOneAttribute:
				if let linkedResource = extractToOneRelationship(serializedData, key: attribute.serializedName, linkedType: toOne.linkedType, resource: resource, linkTemplates: linkTemplates) {
					resource.setValue(linkedResource, forAttribute: attribute.name)
				}
			case let toMany as ToManyAttribute:
				if let linkedResources = extractToManyRelationship(serializedData, key: attribute.serializedName, linkedType: toMany.linkedType, resource: resource, linkTemplates: linkTemplates) {
					resource.setValue(linkedResources, forAttribute: attribute.name)
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
	private func extractToOneRelationship(serializedData: JSON, key: String, linkedType: String, resource: ResourceProtocol, linkTemplates: JSON? = nil) -> ResourceProtocol? {
		var resource: ResourceProtocol? = nil
		
		// Resource level link
		if let linkData = serializedData["links"][key].dictionary {
			let type = linkData["type"]?.string ?? linkedType
			let id = linkData["id"]?.stringValue
			
			resource = resourceFactory.dispense(type, id: id!, pool: &resources)
			
			if let resourceURL = linkData["resource"]?.stringValue {
				resource!.URL = NSURL(string: resourceURL)
			}
			
		}
		
		return resource
	}
	
	/**
	Extracts the to-many relationship for the given key from the passed serialized data.
	
	This method supports both the array of IDs form and the resource object forms.
	
	:param: serializedData The data from which to extract the relationship.
	:param: key            The key for which to extract the relationship from the data.
	
	:returns: The extracted relationship or nil if no relationship with the given key was found in the data.
	*/
	private func extractToManyRelationship(serializedData: JSON, key: String, linkedType: String, resource: ResourceProtocol, linkTemplates: JSON? = nil) -> ResourceCollection? {
		var resourceCollection: ResourceCollection? = nil
		
		// Resource level link
		if let linkData = serializedData["links"][key].dictionary {
			var type: String = linkData["type"]?.string ?? linkedType
			var ids: [String]? = linkData["ids"]?.array?.map { $0.stringValue }
			var resourcesURL: NSURL? = linkData["resource"]?.URL
			var linkURL: NSURL? = linkData["self"]?.URL
			
			resourceCollection =  ResourceCollection(resourcesURL: resourcesURL, URL: linkURL, type: type, ids: ids)
		}
		
		return resourceCollection
	}
	
	/**
	Resolves the relations of the resources in the store.
	*/
	private func resolveRelations() {
		for resource in resources {
			for attribute in resource.attributes {
				
				if let toManyAttribute = attribute as? ToManyAttribute {
					if let linkedResource = resource.valueForAttribute(attribute.name) as? ResourceCollection {
						
						// We can only resolve if IDs are known
						if let ids = linkedResource.ids {
							var targetResources: [ResourceProtocol] = []
							
							for id in ids {
								// Find target of relation in store
								if let targetResource = findResource(resources, linkedResource.type, id) {
									targetResources.append(targetResource)
								} else {
									//println("Cannot resolve to-many link \(resource.type):\(resource.id!) - \(attribute.name) -> \(linkedResource.type):\(id) because the linked resource does not exist in the store.")
								}
							}
							
							linkedResource.fulfill(targetResources)
						} else {
							//println("Cannot resolve to-many link \(resource.type):\(resource.id!) - \(attribute.name) -> \(linkedResource.type):? because the foreign IDs are not known.")
						}
					} else {
						//println("Cannot resolve to-many link \(resource.type):\(resource.id!) - \(attribute.name) -> ? because the link data is not fetched.")
					}
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