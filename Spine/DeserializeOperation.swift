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
A DeserializeOperation deserializes JSON data in the form of NSData to a JSONAPIDocument.
*/
class DeserializeOperation: NSOperation {
	
	// Input
	private let data: JSON
	private let valueFormatters: ValueFormatterRegistry
	private let resourceFactory: ResourceFactory
	private let keyFormatter: KeyFormatter
	
	// Extracted objects
	private var extractedPrimaryResources: [Resource] = []
	private var extractedIncludedResources: [Resource] = []
	private var extractedErrors: [NSError]?
	private var extractedMeta: [String: AnyObject]?
	private var extractedLinks: [String: NSURL]?
	private var extractedJSONAPI: [String: AnyObject]?
	private var resourcePool: [Resource] = []
	
	// Output
	var result: Failable<JSONAPIDocument>?
	
	
	// MARK: Initializers
	
	init(data: NSData, resourceFactory: ResourceFactory, valueFormatters: ValueFormatterRegistry, keyFormatter: KeyFormatter) {
		self.data = JSON(data: data)
		self.resourceFactory = resourceFactory
		self.valueFormatters = valueFormatters
		self.keyFormatter = keyFormatter
	}
	
	
	// MARK: Mapping targets
	
	func addMappingTargets(targets: [Resource]) {		
		resourcePool += targets
	}
	
	
	// MARK: NSOperation
	
	override func main() {
		// Validate document
		guard data.dictionary != nil else {
			let errorMessage = "The given JSON is not a dictionary (hash).";
			Spine.logError(.Serializing, errorMessage)
			result = Failable(NSError(domain: SpineSerializingErrorDomain, code: SpineErrorCodes.InvalidDocumentStructure, userInfo: [NSLocalizedDescriptionKey: errorMessage]))
			return
		}
		guard data["errors"] != nil || data["data"] != nil || data["meta"] != nil else {
			let errorMessage = "Either 'data', 'errors', or 'meta' must be present in the top level.";
			Spine.logError(.Serializing, errorMessage)
			result = Failable(NSError(domain: SpineSerializingErrorDomain, code: SpineErrorCodes.InvalidDocumentStructure, userInfo: [NSLocalizedDescriptionKey: errorMessage]))
			return
		}
		guard (data["errors"] == nil && data["data"] != nil) || (data["errors"] != nil && data["data"] == nil) else {
			let errorMessage = "Top level 'data' and 'errors' must not coexist in the same document.";
			Spine.logError(.Serializing, errorMessage)
			result = Failable(NSError(domain: SpineSerializingErrorDomain, code: SpineErrorCodes.InvalidDocumentStructure, userInfo: [NSLocalizedDescriptionKey: errorMessage]))
			return
		}
		
		// Extract resources
		do {
			if let data = self.data["data"].array {
				for (index, representation) in data.enumerate() {
					try extractedPrimaryResources.append(deserializeSingleRepresentation(representation, mappingTargetIndex: index))
				}
			} else if let _ = self.data["data"].dictionary {
				try extractedPrimaryResources.append(deserializeSingleRepresentation(self.data["data"], mappingTargetIndex: resourcePool.startIndex))
			}

			if let data = self.data["included"].array {
				for representation in data {
					try extractedIncludedResources.append(deserializeSingleRepresentation(representation))
				}
			}
		} catch let error as NSError {
			result = Failable(error)
			return
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
		
		// Extract jsonapi
		extractedJSONAPI = self.data["jsonapi"].dictionaryObject
		
		// Resolve relations in the store
		resolveRelations()
		
		// Create a result
		var responseDocument = JSONAPIDocument(data: nil, included: nil, errors: extractedErrors, meta: extractedMeta, links: extractedLinks, jsonapi: extractedJSONAPI)
		if !extractedPrimaryResources.isEmpty {
			responseDocument.data = extractedPrimaryResources
		}
		if !extractedIncludedResources.isEmpty {
			responseDocument.included = extractedIncludedResources
		}
		result = Failable(responseDocument)
	}
	
	
	// MARK: Deserializing
	
	/**
	Maps a single resource representation into a resource object of the given type.
	
	- parameter representation:     The JSON representation of a single resource.
	- parameter mappingTargetIndex: The index of the matching mapping target.
	
	- returns: A Resource object with values mapped from the representation.
	*/
	private func deserializeSingleRepresentation(representation: JSON, mappingTargetIndex: Int? = nil) throws -> Resource {
		guard representation.dictionary != nil else {
			throw NSError(domain: SpineSerializingErrorDomain, code: SpineErrorCodes.InvalidResourceStructure, userInfo: nil)
		}
		
		guard let type: ResourceType = representation["type"].string else {
			throw NSError(domain: SpineSerializingErrorDomain, code: SpineErrorCodes.ResourceTypeMissing, userInfo: nil)
		}
		
		guard let id = representation["id"].string else {
			throw NSError(domain: SpineSerializingErrorDomain, code: SpineErrorCodes.ResourceIDMissing, userInfo: nil)
		}
		
		// Dispense a resource
		let resource = resourceFactory.dispense(type, id: id, pool: &resourcePool, index: mappingTargetIndex)
		
		// Extract data
		resource.id = id
		resource.URL = representation["links"]["self"].URL
		resource.meta = representation["meta"].dictionaryObject
		extractAttributes(representation, intoResource: resource)
		extractRelationships(representation, intoResource: resource)
		
		resource.isLoaded = true
		
		return resource
	}
	
	
	// MARK: Attributes
	
	/**
	Extracts the attributes from the given data into the given resource.
	
	This method loops over all the attributes in the passed resource, maps the attribute name
	to the key for the serialized form and invokes `extractAttribute`. It then formats the extracted
	attribute and sets the formatted value on the resource.
	
	- parameter serializedData: The data from which to extract the attributes.
	- parameter resource:       The resource into which to extract the attributes.
	*/
	private func extractAttributes(serializedData: JSON, intoResource resource: Resource) {
		for case let field as Attribute in resource.fields {
			let key = keyFormatter.format(field)
			if let extractedValue: AnyObject = self.extractAttribute(serializedData, key: key) {
				let formattedValue: AnyObject = self.valueFormatters.unformat(extractedValue, forAttribute: field)
				resource.setValue(formattedValue, forField: field.name)
			}
		}
	}
	
	/**
	Extracts the value for the given key from the passed serialized data.
	
	- parameter serializedData: The data from which to extract the attribute.
	- parameter key:            The key for which to extract the value from the data.
	
	- returns: The extracted value or nil if no attribute with the given key was found in the data.
	*/
	private func extractAttribute(serializedData: JSON, key: String) -> AnyObject? {
		let value = serializedData["attributes"][key]
		
		if let _ = value.null {
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
	It also sets `relationships` dictionary on parent resource containing the links to all related resources.
	
	- parameter serializedData: The data from which to extract the relationships.
	- parameter resource:       The resource into which to extract the relationships.
	*/
	private func extractRelationships(serializedData: JSON, intoResource resource: Resource) {
		resource.relationships = [String: [String: AnyObject]]()

		for field in resource.fields {
			let key = keyFormatter.format(field)
			resource.relationships![field.name] = serializedData["relationships"][key].dictionaryObject

			switch field {
			case let toOne as ToOneRelationship:
				if let linkedResource = extractToOneRelationship(serializedData, key: key, linkedType: toOne.linkedType.resourceType, resource: resource) {
					if linkedResource.isLoaded || resource.valueForField(toOne.name) == nil {
						resource.setValue(linkedResource, forField: toOne.name)
					}
				}
			case let toMany as ToManyRelationship:
				if let linkedResourceCollection = extractToManyRelationship(serializedData, key: key, resource: resource) {
					if linkedResourceCollection.linkage != nil || resource.valueForField(toMany.name) == nil {
						resource.setValue(linkedResourceCollection, forField: toMany.name)
					}
				}
			default: ()
			}
		}
	}
	
	/**
	Extracts the to-one relationship for the given key from the passed serialized data.
	
	This method supports both the single ID form and the resource object forms.
	
	- parameter serializedData: The data from which to extract the relationship.
	- parameter key:            The key for which to extract the relationship from the data.
	
	- returns: The extracted relationship or nil if no relationship with the given key was found in the data.
	*/
	private func extractToOneRelationship(serializedData: JSON, key: String, linkedType: ResourceType, resource: Resource) -> Resource? {
		var resource: Resource? = nil
		
		if let linkData = serializedData["relationships"][key].dictionary {
			let type = linkData["data"]?["type"].string ?? linkedType
			
			if let id = linkData["data"]?["id"].string {
				resource = resourceFactory.dispense(type, id: id, pool: &resourcePool)
			} else {
				resource = resourceFactory.instantiate(type)
			}
			
			if let resourceURL = linkData["links"]?["related"].URL {
				resource!.URL = resourceURL
			}
			
		}
		
		return resource
	}
	
	/**
	Extracts the to-many relationship for the given key from the passed serialized data.
	
	This method supports both the array of IDs form and the resource object forms.
	
	- parameter serializedData: The data from which to extract the relationship.
	- parameter key:            The key for which to extract the relationship from the data.
	
	- returns: The extracted relationship or nil if no relationship with the given key was found in the data.
	*/
	private func extractToManyRelationship(serializedData: JSON, key: String, resource: Resource) -> LinkedResourceCollection? {
		var resourceCollection: LinkedResourceCollection? = nil

		if let linkData = serializedData["relationships"][key].dictionary {
			let resourcesURL: NSURL? = linkData["links"]?["related"].URL
			let linkURL: NSURL? = linkData["links"]?["self"].URL
			
			if let linkage = linkData["data"]?.array {
				let mappedLinkage = linkage.map { ResourceIdentifier(type: $0["type"].stringValue, id: $0["id"].stringValue) }
				resourceCollection = LinkedResourceCollection(resourcesURL: resourcesURL, linkURL: linkURL, linkage: mappedLinkage)
			} else {
				resourceCollection = LinkedResourceCollection(resourcesURL: resourcesURL, linkURL: linkURL, linkage: nil)
			}
		}
		
		return resourceCollection
	}
	
	/**
	Resolves the relations of the fetched resources.
	*/
	private func resolveRelations() {
		for resource in resourcePool {
			for case let field as ToManyRelationship in resource.fields {
				
				guard let linkedResourceCollection = resource.valueForField(field.name) as? LinkedResourceCollection else {
					Spine.logInfo(.Serializing, "Cannot resolve to-many link \(resource.resourceType):\(resource.id!) - \(field.name) because the linked collection is not fetched.")
					continue
				}
				
				guard let linkage = linkedResourceCollection.linkage else {
					Spine.logInfo(.Serializing, "Cannot resolve to-many link \(resource.resourceType):\(resource.id!) - \(field.name) because the linkage is not known.")
					continue
				}
					
				let targetResources = linkage.flatMap { link in
					return self.resourcePool.filter { $0.resourceType == link.type && $0.id == link.id }
				}
				
				if !targetResources.isEmpty {
					linkedResourceCollection.resources = targetResources
					linkedResourceCollection.isLoaded = true
				}
				
			}
		}
	}
}