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
	var result: DeserializationResult?
	
	// Private
	private var extractedPrimaryResources: [ResourceProtocol] = []
	private var resourcePool: [ResourceProtocol] = []
	private var paginationData: Pagination?
	
	
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
		// Check if the given data is in the expected format
		if (data.dictionary == nil) {
			Spine.logError(.Serializing, "Cannot deserialize: The given JSON representation was not as expected.")
			result = .Failure(NSError(domain: SpineClientErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey: "The given JSON representation was not as expected."]))
			return
		}
		
		// Extract main resources. The are added to the `extractedPrimaryResources` so we can return them separate from the entire resource pool.
		if let data = self.data["data"].array {
			for (index, representation) in enumerate(data) {
				extractedPrimaryResources.append(deserializeSingleRepresentation(representation, mappingTargetIndex: index))
			}
		} else if let data = self.data["data"].dictionary {
			extractedPrimaryResources.append(deserializeSingleRepresentation(self.data["data"], mappingTargetIndex: 0))
		}
		
		// Extract included resources
		if let data = self.data["included"].array {
			for representation in data {
				deserializeSingleRepresentation(representation)
			}
		}
		
		// Extract meta
		extractMeta()
		
		// Resolve relations in the store
		resolveRelations()
		
		// Create a result
		result = .Success(extractedPrimaryResources)
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
		
		assert(type != nil, "The given JSON representation does have a string 'type'.")
		assert(id != nil, "The given JSON representation does not have a string 'id'.")
		
		// Dispense a resource
		let resource = resourceFactory.dispense(type, id: id, pool: &resourcePool, index: mappingTargetIndex)
		
		// Extract ID
		resource.id = representation["id"].string
		
		// Extract self link
		if let URL = representation["links"]["self"].URL {
			resource.URL = URL
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
		if let linkedResourceURL = serializedData["links"][key].URL {
			resource = resourceFactory.instantiate(linkedType)
			resource?.URL = linkedResourceURL
			
		// Resource level link as a link object. This might contain linkage in the form of type/id.
		} else if serializedData["links"][key].dictionary != nil{
			let linkData = serializedData["links"][key]
			let type = linkData["linkage"]["type"].string ?? linkedType
			
			if let id = linkData["linkage"]["id"].string {
				resource = resourceFactory.dispense(type, id: id, pool: &resourcePool)
			} else {
				resource = resourceFactory.instantiate(type)
			}
			
			if let resourceURL = linkData["related"].URL {
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
		if let linkedResourcesURL = serializedData["links"][key].URL {
			resourceCollection = LinkedResourceCollection(resourcesURL: linkedResourcesURL, URL: nil, linkage: nil)
		
		// Resource level link as a link object. This might contain linkage in the form of type/id.
		} else if serializedData["links"][key].dictionary != nil {
			let linkData = serializedData["links"][key]
			let resourcesURL: NSURL? = linkData["related"].URL
			let linkURL: NSURL? = linkData["self"].URL
			
			if let linkage = linkData["linkage"].array {
				let mappedLinkage = linkage.map { ResourceIdentifier(type: $0["type"].stringValue, id: $0["id"].stringValue) }
				resourceCollection = LinkedResourceCollection(resourcesURL: resourcesURL, URL: linkURL, linkage: mappedLinkage)
			} else {
				resourceCollection = LinkedResourceCollection(resourcesURL: resourcesURL, URL: linkURL, linkage: nil)
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
	
	// MARK: Meta
	
	private func extractMeta() {
		//
	}
}