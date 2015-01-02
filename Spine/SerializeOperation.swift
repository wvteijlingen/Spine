//
//  SerializeOperation.swift
//  Spine
//
//  Created by Ward van Teijlingen on 30-12-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation
import SwiftyJSON

/**
*  A SerializeOperation is responsible for serializing resource into a multidimensional dictionary/array structure.
*  The resouces are converted to their serialized form using a layered process.
*
*  This process is the inverse of that of the DeserializeOperation.
*/
class SerializeOperation: NSOperation {
	
	private let resources: [Resource]
	private let transformers = TransformerDirectory()
	private let options: SerializationOptions
	
	var result: [String: AnyObject]?
	
	init(resources: [Resource], options: SerializationOptions) {
		self.resources = resources
		self.options = options
	}
	
	override func main() {
		if self.resources.count == 1 {
			let resource = self.resources.first!
			let serializedData = self.serializeResource(resource)
			self.result = [resource.type: serializedData]
			
		} else  {
			var dictionary: [String: [[String: AnyObject]]] = [:]
			
			for resource in resources {
				var serializedData = self.serializeResource(resource)
				
				//Add the resource representation to the root dictionary
				if dictionary[resource.type] == nil {
					dictionary[resource.type] = [serializedData]
				} else {
					dictionary[resource.type]!.append(serializedData)
				}
			}
			
			self.result = dictionary
		}
	}
	
	private func serializeResource(resource: Resource) -> [String: AnyObject] {
		var serializedData: [String: AnyObject] = [:]
		
		// Special attributes
		if let ID = resource.id {
			self.addID(&serializedData, ID: ID)
		}
		
		self.addAttributes(&serializedData, resource: resource)
		self.addRelationships(&serializedData, resource: resource)
		
		return serializedData
	}
	
	
	// MARK: Special attributes
	
	/**
	Adds the given ID to the passed serialized data.
	
	:param: serializedData The data to add the ID to.
	:param: ID             The ID to add.
	*/
	private func addID(inout serializedData: [String: AnyObject], ID: String) {
		serializedData["id"] = ID
	}
	
	
	// MARK: Attributes
	
	/**
	Adds the attributes of the the given resource to the passed serialized data.
	
	This method loops over all the attributes in the passed resource, maps the attribute name
	to the key for the serialized form and formats the value of the attribute. It then passes
	the key and value to the addAttribute method.
	
	:param: serializedData The data to add the attributes to.
	:param: resource       The resource whose attributes to add.
	*/
	private func addAttributes(inout serializedData: [String: AnyObject], resource: Resource) {
		for attribute in resource.attributes {
			if isRelationship(attribute) {
				continue
			}
			
			//TODO: Dirty checking
			
			let key = attribute.serializedName
			
			if let unformattedValue: AnyObject = resource.valueForKey(attribute.name) {
				self.addAttribute(&serializedData, key: key, value: self.transformers.serialize(unformattedValue, forAttribute: attribute))
			} else {
				self.addAttribute(&serializedData, key: key, value: NSNull())
			}
		}
	}
	
	/**
	Adds the given key/value pair to the passed serialized data.
	
	:param: serializedData The data to add the key/value pair to.
	:param: key            The key to add to the serialized data.
	:param: value          The value to add to the serialized data.
	*/
	private func addAttribute(inout serializedData: [String: AnyObject], key: String, value: AnyObject) {
		serializedData[key] = value
	}
	
	
	// MARK: Relationships
	
	/**
	Adds the relationships of the the given resource to the passed serialized data.
	
	This method loops over all the relationships in the passed resource, maps the attribute name
	to the key for the serialized form and gets the related attributes It then passes the key and
	related resources to either the addToOneRelationship or addToManyRelationship method.
	
	
	:param: serializedData The data to add the relationships to.
	:param: resource       The resource whose relationships to add.
	*/
	private func addRelationships(inout serializedData: [String: AnyObject], resource: Resource) {
		for attribute in resource.attributes {
			if !isRelationship(attribute) {
				continue
			}
			
			let key = attribute.serializedName
			
			switch attribute {
			case let toOne as ToOneAttribute:
				if self.options.includeToOne {
					self.addToOneRelationship(&serializedData, key: key, linkedResource: resource.valueForKey(attribute.name) as? Resource)
				}
			case let toMany as ToManyAttribute:
				if self.options.includeToMany {
					self.addToManyRelationship(&serializedData, key: key, linkedResources: resource.valueForKey(attribute.name) as? ResourceCollection)
				}
			default: ()
			}
		}
	}
	
	/**
	Adds the given resource as a to to-one relationship to the serialized data.
	
	:param: serializedData  The data to add the related resource to.
	:param: key             The key to add to the serialized data.
	:param: relatedResource The related resource to add to the serialized data.
	*/
	private func addToOneRelationship(inout serializedData: [String: AnyObject], key: String, linkedResource: Resource?) {
		var linkData: AnyObject
		
		if let ID = linkedResource?.id {
			linkData = ID
		} else {
			linkData = NSNull()
		}
		
		if serializedData["links"] == nil {
			serializedData["links"] = [key: linkData]
		} else {
			var links: [String: AnyObject] = serializedData["links"]! as [String: AnyObject]
			links[key] = linkData
			serializedData["links"] = links
		}
	}
	
	/**
	Adds the given resources as a to to-many relationship to the serialized data.
	
	:param: serializedData   The data to add the related resources to.
	:param: key              The key to add to the serialized data.
	:param: relatedResources The related resources to add to the serialized data.
	*/
	private func addToManyRelationship(inout serializedData: [String: AnyObject], key: String, linkedResources: ResourceCollection?) {
		var linkData: AnyObject
		
		if let resources = linkedResources?.resources {
			let IDs: [String] = resources.filter { resource in
				return resource.id != nil
				}.map { resource in
					return resource.id!
			}
			
			linkData = IDs
			
		} else {
			linkData = []
		}
		
		if serializedData["links"] == nil {
			serializedData["links"] = [key: linkData]
		} else {
			var links: [String: AnyObject] = serializedData["links"]! as [String: AnyObject]
			links[key] = linkData
			serializedData["links"] = links
		}
	}
}