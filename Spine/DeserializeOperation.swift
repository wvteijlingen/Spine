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
	private var extractedPrimaryResources: [ResourceProtocol] = []
	private var resourcePool: [ResourceProtocol] = []
	private var paginationData: PaginationData?
	
	
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
			result = .Failure(NSError(domain: SPINE_ERROR_DOMAIN, code: 0, userInfo: [NSLocalizedDescriptionKey: "The given JSON representation was not as expected."]))
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
		
		// Extract linked resources
		if let data = self.data["linked"].array {
			for representation in data {
				deserializeSingleRepresentation(representation)
			}
		}
		
		// Extract meta
		extractMeta()
		
		// Resolve relations in the store
		resolveRelations()
		
		// Create a result
		result = .Success(resources: extractedPrimaryResources, pagination: paginationData)
	}
	
	
	// MARK: Deserializing
	
	/**
	Maps a single resource representation into a resource object of the given type.
	
	:param: representation The JSON representation of a single resource.
	:param: resourceType   The type of resource onto which to map the representation.
	*/
	private func deserializeSingleRepresentation(representation: JSON, mappingTargetIndex: Int? = nil) -> ResourceProtocol {
		assert(representation.dictionary != nil, "The given JSON representation is not an object (dictionary/hash).")
		
		let type: String! = representation["type"].string
		let id: String! = representation["id"].string
		
		assert(type != nil, "The given JSON representation does have a type.")
		assert(id != nil, "The given JSON representation does not have an id.")
		
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
	private func extractRelationships(serializedData: JSON, intoResource resource: ResourceProtocol) {
		for attribute in resource.attributes {
			switch attribute {
			case let toOne as ToOneAttribute:
				if let linkedResource = extractToOneRelationship(serializedData, key: toOne.serializedName, linkedType: toOne.linkedType, resource: resource) {
					resource.setValue(linkedResource, forAttribute: toOne.name)
				}
			case let toMany as ToManyAttribute:
				if let linkedResourceCollection = extractToManyRelationship(serializedData, key: toMany.serializedName, resource: resource) {
					resource.setValue(linkedResourceCollection, forAttribute: toMany.name)
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
	private func extractToOneRelationship(serializedData: JSON, key: String, linkedType: String, resource: ResourceProtocol) -> ResourceProtocol? {
		var resource: ResourceProtocol? = nil
		
		// Resource level link as a resource URL only.
		if let linkedResourceURL = serializedData["links"][key].URL {
			resource = resourceFactory.instantiate(linkedType)
			resource?.URL = linkedResourceURL
			
		// Resource level link as a link object. This might contain linkage in the form of type/id.
		} else if serializedData["links"][key].dictionary != nil{
			let linkData = serializedData["links"][key]
			let type = linkData["type"].string ?? linkedType
			
			if let id = linkData["id"].string {
				resource = resourceFactory.dispense(type, id: id, pool: &resourcePool)
			} else {
				resource = resourceFactory.instantiate(type)
			}
			
			if let resourceURL = linkData["resource"].URL {
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
			resourceCollection = LinkedResourceCollection(resourcesURL: linkedResourcesURL, URL: nil)
		
		// Resource level link as a link object. This might contain linkage in the form of type/id.
		} else if serializedData["links"][key].dictionary != nil {
			let linkData = serializedData["links"][key]
			let resourcesURL: NSURL? = linkData["resource"].URL
			let linkURL: NSURL? = linkData["self"].URL
			
			// Homogenous
			if let homogenousType = linkData["type"].string {
				if let ids = linkData["ids"].array {
					resourceCollection = LinkedResourceCollection(resourcesURL: resourcesURL, URL: linkURL, homogenousType: homogenousType, linkage: ids.map { $0.stringValue })
				}
			
			// Heterogenous
			} else if let heterogenousLinkage = linkData["data"].array {
				let linkage = heterogenousLinkage.map { (type: $0["type"].stringValue, id: $0["id"].stringValue) }
				resourceCollection = LinkedResourceCollection(resourcesURL: resourcesURL, URL: linkURL, linkage: linkage)
			}
			
			// Other
			else {
				resourceCollection = LinkedResourceCollection(resourcesURL: resourcesURL, URL: linkURL)
			}
		}
		
		return resourceCollection
	}
	
	/**
	Resolves the relations of the primary resources.
	*/
	private func resolveRelations() {
		for resource in resourcePool {
			for attribute in resource.attributes {
				
				if let toManyAttribute = attribute as? ToManyAttribute {
					if let linkedResource = resource.valueForAttribute(attribute.name) as? LinkedResourceCollection {
						
						// We can only resolve if the linkage is known
						if let linkage = linkedResource.linkage {
							var targetResources: [ResourceProtocol] = []
							
							for link in linkage {
								// Find target of relation in store
								if let targetResource = findResource(resourcePool, link.type, link.id) {
									targetResources.append(targetResource)
								} else {
									//println("Cannot resolve to-many link \(resource.type):\(resource.id!) - \(attribute.name) -> \(linkedResource.type):\(id) because the linked resource does not exist in the store.")
								}
							}
							
							if !isEmpty(targetResources) {
								linkedResource.resources = targetResources
								linkedResource.isLoaded = true
							}
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
		if let meta = self.data["links"].dictionary {
			var paginationData = PaginationData(
				count: meta["count"]?.int,
				limit: meta["limit"]?.int,
				beforeCursor: meta["before_cursor"]?.string,
				afterCursor: meta["after_cursor"]?.string,
				firstURL: nil,
				lastURL: nil,
				nextURL: nil,
				previousURL: nil
			)
			
			if let firstURL = meta["first"]?.URL {
				paginationData.firstURL = firstURL
			}
			
			if let lastURL = meta["last"]?.URL {
				paginationData.lastURL = lastURL
			}
			
			if let nextURL = meta["next"]?.URL {
				paginationData.nextURL = nextURL
			}
			
			if let previousURL = meta["prev"]?.URL {
				paginationData.previousURL = previousURL
			}
			
			self.paginationData = paginationData
		}
	}
}