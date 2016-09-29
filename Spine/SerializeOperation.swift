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
A SerializeOperation serializes a JSONAPIDocument to JSON data in the form of NSData.
*/
class SerializeOperation: Operation {
	fileprivate let resources: [Resource]
	let valueFormatters: ValueFormatterRegistry
	let keyFormatter: KeyFormatter
	var options: SerializationOptions = [.IncludeID]
	
	var result: Failable<Data, SerializerError>?
	
	
	// MARK: -
	
	init(document: JSONAPIDocument, valueFormatters: ValueFormatterRegistry, keyFormatter: KeyFormatter) {
		self.resources = document.data ?? []
		self.valueFormatters = valueFormatters
		self.keyFormatter = keyFormatter
	}
	
	override func main() {
		let serializedData: Any
		
		if resources.count == 1 {
			serializedData = serializeResource(resources.first!)
		} else  {
			serializedData = resources.map { resource in
				serializeResource(resource)
			}
		}
		
		do {
			let serialized = try JSONSerialization.data(withJSONObject: ["data": serializedData], options: JSONSerialization.WritingOptions(rawValue: 0))
			result = Failable.success(serialized)
		} catch let error as NSError {
			result = Failable.failure(SerializerError.jsonSerializationError(error))
		}
	}
	
	
	// MARK: Serializing
	
	fileprivate func serializeResource(_ resource: Resource) -> [String: Any] {
		Spine.logDebug(.serializing, "Serializing resource \(resource) of type '\(resource.resourceType)' with id '\(resource.id)'")
		
		var serializedData: [String: Any] = [:]
		
		// Serialize ID
		if let id = resource.id , options.contains(.IncludeID) {
			serializedData["id"] = id as AnyObject?
		}
		
		// Serialize type
		serializedData["type"] = resource.resourceType as AnyObject?
		
		// Serialize fields
		addAttributes(from: resource, to: &serializedData )
		addRelationships(from: resource, to: &serializedData)
		
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
	fileprivate func addAttributes(from resource: Resource, to serializedData: inout [String: Any]) {
		var attributes = [String: Any]();
		
		for case let field as Attribute in resource.fields where field.isReadOnly == false {
			let key = keyFormatter.format(field)
			
			Spine.logDebug(.serializing, "Serializing attribute \(field) as '\(key)'")
			
			//TODO: Dirty checking
			if let unformattedValue = resource.value(forField: field.name) {
				addAttribute(&attributes, key: key, value: valueFormatters.formatValue(unformattedValue, forAttribute: field))
			} else if(!options.contains(.OmitNullValues)){
				addAttribute(&attributes, key: key, value: NSNull())
			}
		}
		
		serializedData["attributes"] = attributes as AnyObject?
	}
	
	/**
	Adds the given key/value pair to the passed serialized data.
	
	- parameter serializedData: The data to add the key/value pair to.
	- parameter key:            The key to add to the serialized data.
	- parameter value:          The value to add to the serialized data.
	*/
	fileprivate func addAttribute(_ serializedData: inout [String: Any], key: String, value: Any) {
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
	fileprivate func addRelationships(from resource: Resource, to serializedData: inout [String: Any]) {
		for case let field as Relationship in resource.fields where field.isReadOnly == false {
			let key = keyFormatter.format(field)
			
			Spine.logDebug(.serializing, "Serializing relationship \(field) as '\(key)'")
			
			switch field {
			case let toOne as ToOneRelationship:
				if options.contains(.IncludeToOne) {
					addToOneRelationship(resource.value(forField: field.name) as? Resource, to: &serializedData, key: key, type: toOne.linkedType.resourceType)
				}
			case let toMany as ToManyRelationship:
				if options.contains(.IncludeToMany) {
					addToManyRelationship(resource.value(forField: field.name) as? ResourceCollection, to: &serializedData, key: key, type: toMany.linkedType.resourceType)
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
	fileprivate func addToOneRelationship(_ linkedResource: Resource?, to serializedData: inout [String: Any], key: String, type: ResourceType) {
		let serializedId: Any
		if let resourceId = linkedResource?.id {
			serializedId = resourceId
		} else {
			serializedId = NSNull()
		}
		
		let serializedRelationship = [
			"data": [
				"type": type,
				"id": serializedId
			]
		]
		
		if serializedData["relationships"] == nil {
			serializedData["relationships"] = [key: serializedRelationship]
		} else {
			var relationships = serializedData["relationships"] as! [String: Any]
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
	fileprivate func addToManyRelationship(_ linkedResources: ResourceCollection?, to serializedData: inout [String: Any], key: String, type: ResourceType) {
		var resourceIdentifiers: [ResourceIdentifier] = []
		
		if let resources = linkedResources?.resources {
			resourceIdentifiers = resources.filter { $0.id != nil }.map { resource in
				return ResourceIdentifier(type: resource.resourceType, id: resource.id!)
			}
		}
		
		let serializedRelationship = [
			"data": resourceIdentifiers.map { $0.toDictionary() }
		]
		
		if serializedData["relationships"] == nil {
			serializedData["relationships"] = [key: serializedRelationship]
		} else {
			var relationships = serializedData["relationships"] as! [String: Any]
			relationships[key] = serializedRelationship
			serializedData["relationships"] = relationships
		}
	}
}
