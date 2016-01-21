//
//  Serializing.swift
//  Spine
//
//  Created by Ward van Teijlingen on 23-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation

/**
Serializer (de)serializes according to the JSON:API specification.
*/
public class Serializer {
	/// The resource factory used for dispensing resources.
	private var resourceFactory = ResourceFactory()
	
	/// The transformers used for transforming to and from the serialized representation.
	private var valueFormatters = ValueFormatterRegistry.defaultRegistry()
	
	/// The key formatter used for formatting field names to keys.
	public var keyFormatter: KeyFormatter = AsIsKeyFormatter()
	
	public init() {}
	
	/**
	Deserializes the given data into a JSONAPIDocument.
	
	- parameter data:           The data to deserialize.
	- parameter mappingTargets: Optional resources onto which data will be deserialized.
	
	- throws: NSError that can occur in the deserialization.
	
	- returns: A JSONAPIDocument.
	*/
	public func deserializeData(data: NSData, mappingTargets: [Resource]? = nil) throws -> JSONAPIDocument {
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
	public func serializeDocument(document: JSONAPIDocument, options: SerializationOptions = [.IncludeID]) throws -> NSData {
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
	public func serializeResources(resources: [Resource], options: SerializationOptions = [.IncludeID]) throws -> NSData {
		let document = JSONAPIDocument(data: resources, included: nil, errors: nil, meta: nil, links: nil, jsonapi: nil)
		return try serializeDocument(document, options: options)
	}

	/**
	Registers a resource class.
	
	- parameter resourceClass: The resource class to register.
	*/
	public func registerResource(resourceClass: Resource.Type) {
		resourceFactory.registerResource(resourceClass)
	}
	
	/**
	Registers transformer `transformer`.
	
	- parameter transformer: The Transformer to register.
	*/
	public func registerValueFormatter<T: ValueFormatter>(formatter: T) {
		valueFormatters.registerFormatter(formatter)
	}
}

/**
A JSONAPIDocument represents a JSON API document containing
resources, errors, metadata, links and jsonapi data.
*/
public struct JSONAPIDocument {
	/// Primary resources extracted from the response.
	public var data: [Resource]?
	
	/// Included resources extracted from the response.
	public var included: [Resource]?
	
	/// Errors extracted from the response.
	public var errors: [APIError]?
	
	/// Metadata extracted from the reponse.
	public var meta: [String: AnyObject]?
	
	/// Links extracted from the response.
	public var links: [String: NSURL]?
	
	/// JSONAPI information extracted from the response.
	public var jsonapi: [String: AnyObject]?
}

public struct SerializationOptions: OptionSetType {
	public let rawValue: Int
	public init(rawValue: Int) { self.rawValue = rawValue }
	
	/// Whether to include the resource ID in the serialized representation.
	public static let IncludeID = SerializationOptions(rawValue: 1 << 1)
	
	/// Whether to only serialize fields that are dirty.
	public static let DirtyFieldsOnly = SerializationOptions(rawValue: 1 << 2)
	
	/// Whether to include to-many linked resources in the serialized representation.
	public static let IncludeToMany = SerializationOptions(rawValue: 1 << 3)
	
	/// Whether to include to-one linked resources in the serialized representation.
	public static let IncludeToOne = SerializationOptions(rawValue: 1 << 4)
}