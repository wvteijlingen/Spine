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
A DeserializeOperation is responsible for deserializing a single server response.
The serialized data is converted into Resource instances using a layered process.

This process is the inverse of that of the SerializeOperation.
*/
class DeserializeOperation: NSOperation {
	
	// Input
	let data: JSON
	var transformers: TransformerDirectory = TransformerDirectory()
	var resourceFactory: ResourceFactory
	
	// Output
	var result: Failable<JSONAPIDocument>?
	
	// Extracted objects
	private var extractedPrimaryResources: [ResourceProtocol] = []
	private var extractedErrors: [NSError]?
	private var extractedMeta: [String: AnyObject]?
	private var extractedLinks: [String: NSURL]?
	
	private var resourcePool: [ResourceProtocol] = []
	
	
	// MARK: Initializers
	
	init(data: NSData, resourceFactory: ResourceFactory) {
		self.data = JSON(data: data)
		self.resourceFactory = resourceFactory
	}
	
	
	// MARK: Mapping targets
	
	func addMappingTargets(targets: [ResourceProtocol]) {
		// We can only map onto resources that are not loaded yet
		for resource in targets {
			assert(resource.isLoaded == false, "Cannot map onto loaded resource \(resource)")
		}
		
		resourcePool += targets
	}
	
	
	// MARK: NSOperation
	
	override func main() {		
		// Validate document
		if (data.dictionary == nil) {
			let errorMessage = "Cannot deserialize: The given JSON is not a dictionary (hash).";
			Spine.logError(.Serializing, errorMessage)
			result = Failable(NSError(domain: SpineClientErrorDomain, code: SpineErrorCodes.InvalidDocumentStructure, userInfo: [NSLocalizedDescriptionKey: errorMessage]))
			return
		} else if (data["errors"] == nil && data["data"] == nil && data["meta"] == nil) {
			let errorMessage = "Cannot deserialize: None of the allowed top level keys were found. Either 'data', 'errors', or 'meta' must be present.";
			Spine.logError(.Serializing, errorMessage)
			result = Failable(NSError(domain: SpineClientErrorDomain, code: SpineErrorCodes.InvalidDocumentStructure, userInfo: [NSLocalizedDescriptionKey: errorMessage]))
			return
		} else if(data["errors"] != nil && data["data"] != nil) {
			let errorMessage = "Cannot deserialize: Top level keys 'data' and 'errors' must not coexist in the same document.";
			Spine.logError(.Serializing, errorMessage)
			result = Failable(NSError(domain: SpineClientErrorDomain, code: SpineErrorCodes.InvalidDocumentStructure, userInfo: [NSLocalizedDescriptionKey: errorMessage]))
			return
		}
		
		// Extract main resources. The are added to the `extractedPrimaryResources` so we can return them separate from the entire resource pool.
		if let data = self.data["data"].array {
			for (index, representation) in enumerate(data) {
				extractedPrimaryResources.append(deserializeSingleRepresentation(representation, mappingTargetIndex: index))
			}
		} else if let data = self.data["data"].dictionary {
			extractedPrimaryResources.append(deserializeSingleRepresentation(self.data["data"], mappingTargetIndex: resourcePool.startIndex))
		}
			
		// Extract included resources
		if let data = self.data["included"].array {
			for representation in data {
				deserializeSingleRepresentation(representation)
			}
		}
		
		// Extract errors
		extractedErrors = self.data["errors"].array?.map { error -> NSError in
			let code = error["code"].intValue
			var userInfo = error.dictionaryObject
			if let title = error["title"].string {
				userInfo = [NSLocalizedDescriptionKey: title]
			}
			
			return NSError(domain: SpineServerErrorDomain, code: code, userInfo: userInfo)
		}
		
		// Extract meta
		extractedMeta = self.data["meta"].dictionaryObject
		
		// Extract links
		if let links = self.data["links"].dictionary {
			extractedLinks = [:]
			
			for (key, value) in links {
				extractedLinks![key] = NSURL(string: value.stringValue)!
			}
		}
		
		// Resolve relations in the store
		resolveRelations()
		
		// Create a result
		var responseDocument = JSONAPIDocument(data: nil, errors: extractedErrors, meta: extractedMeta, links: extractedLinks)
		if !isEmpty(extractedPrimaryResources) {
			responseDocument.data = extractedPrimaryResources
		}
		result = Failable(responseDocument)
	}
	
	
	// MARK: Deserializing
	
	/**
	Maps a single resource representation into a resource object of the given type.
	
	:param: representation     The JSON representation of a single resource.
	:param: mappingTargetIndex The index of the matching mapping target.
	
	:returns: A ResourceProtocol object with values mapped from the representation.
	*/
	private func deserializeSingleRepresentation(representation: JSON, mappingTargetIndex: Int? = nil) -> ResourceProtocol {
		assert(representation.dictionary != nil, "The given JSON representation is not an object (dictionary/hash).")
		
		let type: ResourceType! = representation["type"].string
		let id: String! = representation["id"].string
		
		assert(type != nil, "The given JSON representation does not have a string 'type'.")
		assert(id != nil, "The given JSON representation does not have a string 'id'.")
		
		// Dispense a resource
		let resource = resourceFactory.dispense(type, id: id, pool: &resourcePool, index: mappingTargetIndex)
		
		// Extract ID
		resource.id = representation["id"].string
		
		// Extract self link
		if let URL = representation["links"]["self"].URL {
			resource.URL = URL
		}
		
		// Extract meta
		if resource is MetaHoldable {
			(resource as! MetaHoldable).meta = representation["meta"].dictionaryObject
		}

		// Extract fields
		extractAttributes(representation, intoResource: resource)
		extractRelationships(representation, intoResource: resource)
		
		// Set loaded flag
		resource.isLoaded = true
		
		return resource
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
		enumerateFields(resource, Attribute.self) { attribute in
			if let extractedValue: AnyObject = self.extractAttribute(serializedData, key: attribute.serializedName) {
				let formattedValue: AnyObject = self.transformers.deserialize(extractedValue, forAttribute: attribute)
				resource.setValue(formattedValue, forField: attribute.name)
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
		let value = serializedData["attributes"][key]
		
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
	private func extractRelationships(serializedData: JSON, intoResource resource: ResourceProtocol) {
		enumerateFields(resource) { field in
			switch field {
			case let toOne as ToOneRelationship:
				if let linkedResource = self.extractToOneRelationship(serializedData, key: toOne.serializedName, linkedType: toOne.linkedType, resource: resource) {
					resource.setValue(linkedResource, forField: toOne.name)
				}
			case let toMany as ToManyRelationship:
				if let linkedResourceCollection = self.extractToManyRelationship(serializedData, key: toMany.serializedName, resource: resource) {
					resource.setValue(linkedResourceCollection, forField: toMany.name)
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
	private func extractToOneRelationship(serializedData: JSON, key: String, linkedType: ResourceType, resource: ResourceProtocol) -> ResourceProtocol? {
		var resource: ResourceProtocol? = nil
		
		// Resource level link as a resource URL only.
		if let linkedResourceURL = serializedData["relationships"][key].URL {
			resource = resourceFactory.instantiate(linkedType)
			resource?.URL = linkedResourceURL
			
		// Resource level link as a link object. This might contain linkage in the form of type/id.
		} else if serializedData["relationships"][key].dictionary != nil{
			let linkData = serializedData["relationships"][key]
			let type = linkData["data"]["type"].string ?? linkedType
			
			if let id = linkData["data"]["id"].string {
				resource = resourceFactory.dispense(type, id: id, pool: &resourcePool)
			} else {
				resource = resourceFactory.instantiate(type)
			}
			
			if let resourceURL = linkData["links"]["related"].URL {
				resource!.URL = resourceURL
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
	private func extractToManyRelationship(serializedData: JSON, key: String, resource: ResourceProtocol) -> LinkedResourceCollection? {
		var resourceCollection: LinkedResourceCollection? = nil
		
		// Resource level link as a resource URL only.
		if let resourcesURL = serializedData["relationships"][key].URL {
			resourceCollection = LinkedResourceCollection(resourcesURL: resourcesURL, linkURL: nil, linkage: nil)
		
		// Resource level link as a link object. This might contain linkage in the form of type/id.
		} else if serializedData["relationships"][key].dictionary != nil {
			let linkData = serializedData["relationships"][key]
			let resourcesURL: NSURL? = linkData["links"]["related"].URL
			let linkURL: NSURL? = linkData["links"]["self"].URL
			
			if let linkage = linkData["data"].array {
				let mappedLinkage = linkage.map { ResourceIdentifier(type: $0["type"].stringValue, id: $0["id"].stringValue) }
				resourceCollection = LinkedResourceCollection(resourcesURL: resourcesURL, linkURL: linkURL, linkage: mappedLinkage)
			} else {
				resourceCollection = LinkedResourceCollection(resourcesURL: resourcesURL, linkURL: linkURL, linkage: nil)
			}
		}
		
		return resourceCollection
	}
	
	/**
	Resolves the relations of the primary resources.
	*/
	private func resolveRelations() {
		for resource in resourcePool {
			enumerateFields(resource, ToManyRelationship.self) { field in
				if let linkedResource = resource.valueForField(field.name) as? LinkedResourceCollection {
					
					// We can only resolve if the linkage is known
					if let linkage = linkedResource.linkage {
						
						let targetResources: [ResourceProtocol] = linkage.map { link in
							findResource(self.resourcePool, link.type, link.id)
						}.filter { $0 != nil }.map { $0! }
						
						if !isEmpty(targetResources) {
							linkedResource.resources = targetResources
							linkedResource.isLoaded = true
						}
					} else {
						Spine.logInfo(.Serializing, "Cannot resolve to-many link \(resource.type):\(resource.id!) - \(field.name) because the foreign IDs are not known.")
					}
				} else {
					Spine.logInfo(.Serializing, "Cannot resolve to-many link \(resource.type):\(resource.id!) - \(field.name) because the link data is not fetched.")
				}
			}
		}
	}
}