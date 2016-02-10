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
class SerializeOperation: NSOperation {
	private let resources: [Resource]
	let valueFormatters: ValueFormatterRegistry
	let keyFormatter: KeyFormatter
	var options: SerializationOptions = [.IncludeID]
	
	var result: Failable<NSData, SerializerError>?
	
	
	// MARK: Initializers
	
	init(document: JSONAPIDocument, valueFormatters: ValueFormatterRegistry, keyFormatter: KeyFormatter) {
		self.resources = document.data ?? []
		self.valueFormatters = valueFormatters
		self.keyFormatter = keyFormatter
	}
	
	
	// MARK: NSOperation
	
	override func main() {
		let JSON: AnyObject
		
		if resources.count == 1 {
			JSON = serializeResource(resources.first!)
		} else  {
			JSON = resources.map { resource in
				self.serializeResource(resource)
			}
		}
		
		do {
			let serialized = try NSJSONSerialization.dataWithJSONObject(["data": JSON], options: NSJSONWritingOptions(rawValue: 0))
			result = Failable.Success(serialized)
		} catch let error as NSError {
			result = Failable.Failure(SerializerError.JSONSerializationError(error))
		}
	}
	
	
	// MARK: Serializing
	
	private func serializeResource(resource: Resource) -> [String: AnyObject] {
		Spine.logDebug(.Serializing, "Serializing resource \(resource) of type '\(resource.resourceType)' with id '\(resource.id)'")
		
		var serializedData: [String: AnyObject] = [:]
		
		// Serialize ID
		if let ID = resource.id where options.contains(.IncludeID) {
			serializedData["id"] = ID
		}
		
		// Serialize type
		serializedData["type"] = resource.resourceType
		
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
	private func addAttributes(inout serializedData: [String: AnyObject], resource: Resource) {
		var attributes = [String: AnyObject]();
		
		for case let field as Attribute in resource.fields where field.isReadOnly == false {
			let key = keyFormatter.format(field)
			
			Spine.logDebug(.Serializing, "Serializing attribute \(field) as '\(key)'")
			
			//TODO: Dirty checking
			if let unformattedValue: AnyObject = resource.valueForField(field.name) {
				addAttribute(&attributes, key: key, value: self.valueFormatters.format(unformattedValue, forAttribute: field))
			} else {
				addAttribute(&attributes, key: key, value: NSNull())
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
	private func addRelationships(inout serializedData: [String: AnyObject], resource: Resource) {
		for case let field as Relationship in resource.fields where field.isReadOnly == false {
			let key = keyFormatter.format(field)
			
			Spine.logDebug(.Serializing, "Serializing relationship \(field) as '\(key)'")
			
			switch field {
			case let toOne as ToOneRelationship:
				if options.contains(.IncludeToOne) {
					addToOneRelationship(&serializedData, key: key, type: toOne.linkedType.resourceType, linkedResource: resource.valueForField(field.name) as? Resource)
				}
			case let toMany as ToManyRelationship:
				if options.contains(.IncludeToMany) {
					addToManyRelationship(&serializedData, key: key, type: toMany.linkedType.resourceType, linkedResources: resource.valueForField(field.name) as? ResourceCollection)
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
	private func addToOneRelationship(inout serializedData: [String: AnyObject], key: String, type: ResourceType, linkedResource: Resource?) {
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
				return ResourceIdentifier(type: resource.resourceType, id: resource.id!)
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