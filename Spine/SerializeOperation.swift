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
A SerializeOperation is responsible for serializing resource into a multidimensional dictionary/array structure.
The resouces are converted to their serialized form using a layered process.

This process is the inverse of that of the DeserializeOperation.
*/
class SerializeOperation: NSOperation {
	private let resources: [ResourceProtocol]
	var transformers = TransformerDirectory()
	var options = SerializationOptions()
	
	var result: NSData?
	
	
	// MARK: Initializers
	
	init(resources: [ResourceProtocol]) {
		self.resources = resources
	}
	
	
	// MARK: NSOperation
	
	override func main() {
		if resources.count == 1 {
			let serializedData = serializeResource(resources.first!)
			result = try? NSJSONSerialization.dataWithJSONObject(["data": serializedData], options: NSJSONWritingOptions(rawValue: 0))
			
		} else  {
			var data = resources.map { resource in
				self.serializeResource(resource)
			}
			
			result = try? NSJSONSerialization.dataWithJSONObject(["data": data], options: NSJSONWritingOptions(rawValue: 0))
		}
	}
	
	
	// MARK: Serializing
	
	private func serializeResource(resource: ResourceProtocol) -> [String: AnyObject] {
		Spine.logDebug(.Serializing, "Serializing resource \(resource) of type '\(resource.type)' with id '\(resource.id)'")
		
		var serializedData: [String: AnyObject] = [:]
		
		// Serialize ID
		if options.includeID {
			if let ID = resource.id {
				serializedData["id"] = ID
			}
		}
		
		// Serialize type
		serializedData["type"] = resource.type
		
		// Serialize fields
		addAttributes(&serializedData, resource: resource)
		addRelationships(&serializedData, resource: resource)
		
		return serializedData
	}

	
	// MARK: Attributes
	
	/**
	Adds the attributes of the the given resource to the passed serialized data.
	
	This method loops over all the attributes in the passed resource, maps the attribute name
	to the key for the serialized form and formats the value of the attribute. It then passes
	the key and value to the addAttribute method.
	
	- parameter serializedData: The data to add the attributes to.
	- parameter resource:       The resource whose attributes to add.
	*/
	private func addAttributes(inout serializedData: [String: AnyObject], resource: ResourceProtocol) {
		var attributes = [String: AnyObject]();
		
		enumerateFields(resource, type: Attribute.self) { attribute in
			let key = attribute.serializedName
			
			Spine.logDebug(.Serializing, "Serializing attribute \(attribute) with name '\(attribute.name) as '\(key)'")
			
			//TODO: Dirty checking
			if let unformattedValue: AnyObject = resource.valueForField(attribute.name) {
				self.addAttribute(&attributes, key: key, value: self.transformers.serialize(unformattedValue, forAttribute: attribute))
			} else {
				self.addAttribute(&attributes, key: key, value: NSNull())
			}
		}
		
		serializedData["attributes"] = attributes
	}
	
	/**
	Adds the given key/value pair to the passed serialized data.
	
	- parameter serializedData: The data to add the key/value pair to.
	- parameter key:            The key to add to the serialized data.
	- parameter value:          The value to add to the serialized data.
	*/
	private func addAttribute(inout serializedData: [String: AnyObject], key: String, value: AnyObject) {
		serializedData[key] = value
	}
	
	
	// MARK: Relationships
	
	/**
	Adds the relationships of the the given resource to the passed serialized data.
	
	This method loops over all the relationships in the passed resource, maps the attribute name
	to the key for the serialized form and gets the related attributes. It then passes the key and
	related resources to either the addToOneRelationship or addToManyRelationship method.
	
	
	- parameter serializedData: The data to add the relationships to.
	- parameter resource:       The resource whose relationships to add.
	*/
	private func addRelationships(inout serializedData: [String: AnyObject], resource: ResourceProtocol) {
		enumerateFields(resource, type: Relationship.self) { field in
			let key = field.serializedName
			
			Spine.logDebug(.Serializing, "Serializing relationship \(field) with name '\(field.name) as '\(key)'")
			
			switch field {
			case let toOne as ToOneRelationship:
				if self.options.includeToOne {
					self.addToOneRelationship(&serializedData, key: key, type: toOne.linkedType, linkedResource: resource.valueForField(field.name) as? ResourceProtocol)
				}
			case let toMany as ToManyRelationship:
				if self.options.includeToMany {
					self.addToManyRelationship(&serializedData, key: key, type: toMany.linkedType, linkedResources: resource.valueForField(field.name) as? ResourceCollection)
				}
			default: ()
			}
		}
	}
	
	/**
	Adds the given resource as a to to-one relationship to the serialized data.
	
	- parameter serializedData:  The data to add the related resource to.
	- parameter key:             The key to add to the serialized data.
	- parameter relatedResource: The related resource to add to the serialized data.
	*/
	private func addToOneRelationship(inout serializedData: [String: AnyObject], key: String, type: ResourceType, linkedResource: ResourceProtocol?) {
		let serializedRelationship = [
			"data": [
				"type": type,
				"id": linkedResource?.id ?? NSNull()
			]
		]
		
		if serializedData["relationships"] == nil {
			serializedData["relationships"] = [key: serializedRelationship]
		} else {
			var relationships = serializedData["relationships"] as! [String: AnyObject]
			relationships[key] = serializedRelationship
			serializedData["relationships"] = relationships
		}
	}
	
	/**
	Adds the given resources as a to to-many relationship to the serialized data.
	
	- parameter serializedData:   The data to add the related resources to.
	- parameter key:              The key to add to the serialized data.
	- parameter relatedResources: The related resources to add to the serialized data.
	*/
	private func addToManyRelationship(inout serializedData: [String: AnyObject], key: String, type: ResourceType, linkedResources: ResourceCollection?) {
		var resourceIdentifiers: [ResourceIdentifier] = []
		
		if let resources = linkedResources?.resources {
			resourceIdentifiers = resources.filter { $0.id != nil }.map { resource in
				return ResourceIdentifier(type: resource.type, id: resource.id!)
			}
		}
		
		let serializedRelationship = [
			"data": resourceIdentifiers.map { $0.toDictionary() }
		]
		
		if serializedData["relationships"] == nil {
			serializedData["relationships"] = [key: serializedRelationship]
		} else {
			var relationships = serializedData["relationships"] as! [String: AnyObject]
			relationships[key] = serializedRelationship
			serializedData["relationships"] = relationships
		}
	}
}