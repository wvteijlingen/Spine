//
//  Mapping.swift
//  Spine
//
//  Created by Ward van Teijlingen on 23-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation

/**
A JSONAPIDocument represents a JSON API document containing
resources, errors, metadata, links and jsonapi data.
*/
struct JSONAPIDocument {
	/// Primary resources extracted from the response.
	var data: [Resource]?
	
	/// Included resources extracted from the response.
	var included: [Resource]?
	
	/// Errors extracted from the response.
	var errors: [NSError]?
	
	/// Metadata extracted from the reponse.
	var meta: [String: AnyObject]?
	
	/// Links extracted from the response.
	var links: [String: NSURL]?
	
	/// JSONAPI information extracted from the response.
	var jsonapi: [String: AnyObject]?
}


struct SerializationOptions: OptionSetType {
	let rawValue: Int
	init(rawValue: Int) { self.rawValue = rawValue }
	
	/// Whether to include the resource ID in the serialized representation.
	static let IncludeID = SerializationOptions(rawValue: 1 << 1)
	
	/// Whether to only serialize fields that are dirty.
	static let DirtyFieldsOnly = SerializationOptions(rawValue: 1 << 2)
	
	/// Whether to include to-many linked resources in the serialized representation.
	static let IncludeToMany = SerializationOptions(rawValue: 1 << 3)
	
	/// Whether to include to-one linked resources in the serialized representation.
	static let IncludeToOne = SerializationOptions(rawValue: 1 << 4)
}

/**
The built in serializer that (de)serializes according to the JSON:API specification.
*/
class Serializer {
	/// The resource factory used for dispensing resources.
	var resourceFactory: ResourceFactory
	
	/// The transformers used for transforming to and from the serialized representation.
	var valueFormatters: ValueFormatterRegistry
	
	/// The key formatter used for formatting field names to keys.
	var keyFormatter: KeyFormatter
	
	/**
	Initializes a new JSONSerializer.
	
	- parameter resourceFactory: The resource factory to use for creating resource instances. Defaults to empty resource factory.
	- parameter valueFormatters: ValueFormatterRegistry containing value formatters to use for (de)serializing.
	- parameter keyFormatter:    KeyFormatter to use for (un)formatting keys. Defaults to the AsIsKeyFormatter.
	
	- returns: JSONSerializer.
	*/
	init(resourceFactory: ResourceFactory = ResourceFactory(), valueFormatters: ValueFormatterRegistry = ValueFormatterRegistry.defaultRegistry(), keyFormatter: KeyFormatter = AsIsKeyFormatter()) {
		self.resourceFactory = resourceFactory
		self.valueFormatters = valueFormatters
		self.keyFormatter = keyFormatter
	}

	/**
	Deserializes the given data into a JSONAPIDocument.
	
	- parameter data:           The data to deserialize.
	- parameter mappingTargets: Optional resources onto which data will be deserialized.
	
	- throws: NSError that can occur in the deserialization.
	
	- returns: A JSONAPIDocument.
	*/
	func deserializeData(data: NSData, mappingTargets: [Resource]? = nil) throws -> JSONAPIDocument {
		let deserializeOperation = DeserializeOperation(data: data, resourceFactory: resourceFactory, valueFormatters: valueFormatters, keyFormatter: keyFormatter)
		
		if let mappingTargets = mappingTargets {
			deserializeOperation.addMappingTargets(mappingTargets)
		}
		
		deserializeOperation.start()
		
		switch deserializeOperation.result! {
		case .Failure(let error):
			throw error
		case .Success(let document):
			return document
		}
	}
	
	/**
	Serializes the given JSON:API document into NSData. Currently only the main data is serialized.
	
	- parameter document: The JSONAPIDocument to serialize.
	- parameter options:  The serialization options to use.
	
	- throws: NSError that can occur in the serialization.
	
	- returns: Serialized data.
	*/
	func serializeDocument(document: JSONAPIDocument, options: SerializationOptions = [.IncludeID]) throws -> NSData {
		let serializeOperation = SerializeOperation(document: document, valueFormatters: valueFormatters, keyFormatter: keyFormatter)
		serializeOperation.options = options
		
		serializeOperation.start()
		
		switch serializeOperation.result! {
		case .Failure(let error):
			throw error
		case .Success(let data):
			return data
		}
	}
	
	/**
	Serializes the given Resources into NSData.
	
	- parameter resources: The resources to serialize.
	- parameter options:   The serialization options to use.
	
	- throws: NSError that can occur in the serialization.
	
	- returns: Serialized data.
	*/
	func serializeResources(resources: [Resource], options: SerializationOptions = [.IncludeID]) throws -> NSData {
		let document = JSONAPIDocument(data: resources, included: nil, errors: nil, meta: nil, links: nil, jsonapi: nil)
		return try serializeDocument(document, options: options)
	}
}

/**
A ResourceFactory creates resources from given factory funtions.
*/
struct ResourceFactory {
	
	private var factoryFunctions: [ResourceType: () -> Resource] = [:]

	/**
	Registers a given factory function that creates resource with a given type.
	Registering a function for an already registered resource type will override that factory function.
	
	- parameter type:    The resource type for which to register a factory function.
	- parameter factory: The factory function that returns a resource.
	*/
	mutating func registerResource(type: ResourceType, factory: () -> Resource) {
		factoryFunctions[type] = factory
	}

	/**
	Instantiates a resource with the given type, by using a registered factory function.
	
	- parameter type: The resource type to instantiate.
	
	- returns: An instantiated resource.
	*/
	func instantiate(type: ResourceType) -> Resource {
		assert(factoryFunctions[type] != nil, "Cannot instantiate resource of type \(type). You must register this type with Spine first.")
		return factoryFunctions[type]!()
	}
	
	/**
	Dispenses a resource with the given type and id, optionally by finding it in a pool of existing resource instances.
	
	This methods tries to find a resource with the given type and id in the pool. If no matching resource is found,
	it tries to find the nth resource, indicated by `index`, of the given type from the pool. If still no resource is found,
	it instantiates a new resource with the given id and adds this to the pool.
	
	- parameter type:  The resource type to dispense.
	- parameter id:    The id of the resource to dispense.
	- parameter pool:  An array of resources in which to find exisiting matching resources.
	- parameter index: Optional index of the resource in the pool.
	
	- returns: A resource with the given type and id.
	*/
	func dispense(type: ResourceType, id: String, inout pool: [Resource], index: Int? = nil) -> Resource {
		var resource: Resource! = pool.filter { $0.resourceType == type && $0.id == id }.first
		
		if resource == nil && index != nil && !pool.isEmpty {
			let applicableResources = pool.filter { $0.resourceType == type }
			if index! < applicableResources.count {
				resource = applicableResources[index!]
			}
		}
		
		if resource == nil {
			resource = instantiate(type)
			resource.id = id
			pool.append(resource)
		}

		return resource
	}
}