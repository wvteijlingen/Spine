//
//  Mapping.swift
//  Spine
//
//  Created by Ward van Teijlingen on 23-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import UIKit
import SwiftyJSON

typealias DeserializationResult = (store: Store?, pagination: PaginationData?, error: NSError?)

// MARK: - Serializer

protocol SerializerProtocol {
	var resourceFactory: ResourceFactory { get }
	var transformers: TransformerDirectory { get }
	
	// Deserializing
	func deserializeData(data: NSData, usingStore store: Store, options: DeserializationOptions) -> DeserializationResult
	func deserializeError(data: NSData, withResonseStatus responseStatus: Int) -> NSError
	
	// Serializing
	func serializeResources(resources: [ResourceProtocol], options: SerializationOptions) -> [String: AnyObject]
}

/**
*  The serializer is responsible for serializing and deserialing resources.
*  It stores information about the Resource classes using a ResourceClassMap
*  and uses SerializationOperations and DeserialisationOperations for (de)serializing.
*/
class JSONSerializer: SerializerProtocol {
	
	/// The class map that holds information about resource type/class mapping.
	var resourceFactory = ResourceFactory()
	var transformers = TransformerDirectory.defaultTransformerDirectory()
	
	// MARK: Serializing
	
	/**
	Deserializes the given data into a SerializationResult. This is a thin wrapper around
	a DeserializeOperation that does the actual deserialization.
	
	Use this method if you want to deserialize onto existing Resource instances. Otherwise, use
	the regular `deserializeData` method.
	
	:param: data  The data to deserialize.
	:param: store A Store that contains Resource instances onto which data will be deserialize.
	
	:returns: A DeserializationResult that contains either a Store or an error.
	*/
	func deserializeData(data: NSData, usingStore store: Store = Store(), options: DeserializationOptions = DeserializationOptions()) -> DeserializationResult {
		store.resourceFactory = resourceFactory
		
		let deserializeOperation = DeserializeOperation(data: data, store: store)
		deserializeOperation.options = options
		deserializeOperation.transformers = transformers
		
		deserializeOperation.start()
		return deserializeOperation.result!
	}
	
	
	/**
	Deserializes the given data into an NSError. Use this method if the server response is not in the
	200 successful range.
	
	The error returned will contain the error code specified in the `error` section of the response.
	If no error code is available, the given HTTP response status code will be used instead.
	If the `error` section contains a `title` key, it's value will be used for the NSLocalizedDescriptionKey.
	
	:param: data           The data to deserialize.
	:param: responseStatus The HTTP response status which will be used when an error code is absent in the data.
	
	:returns: A NSError deserialized from the given data.
	*/
	func deserializeError(data: NSData, withResonseStatus responseStatus: Int) -> NSError {
		let json = JSON(data as NSData!)
		
		let code = json["errors"][0]["id"].int ?? responseStatus
		
		var userInfo: [String : AnyObject]?
		
		if let errorTitle = json["errors"][0]["title"].string {
			userInfo = [NSLocalizedDescriptionKey: errorTitle]
		}
		
		return NSError(domain: SPINE_API_ERROR_DOMAIN, code: code, userInfo: userInfo)
	}
	
	/**
	Serializes the given Resources into a multidimensional dictionary/array structure
	that can be passed to NSJSONSerialization.
	
	:param: resources The resources to serialize.
	:param: mode      The serialization mode to use.
	
	:returns: A multidimensional dictionary/array structure.
	*/
	func serializeResources(resources: [ResourceProtocol], options: SerializationOptions = SerializationOptions()) -> [String: AnyObject] {
		let serializeOperation = SerializeOperation(resources: resources)
		serializeOperation.options = options
		serializeOperation.transformers = transformers
		
		serializeOperation.start()
		return serializeOperation.result!
	}
}


// MARK: - Options

struct SerializationOptions {
	var includeID = true
	var dirtyAttributesOnly = true
	var includeToMany = false
	var includeToOne = false
	
	init(includeID: Bool = true, dirtyAttributesOnly: Bool = false, includeToMany: Bool = false, includeToOne: Bool = false) {
		self.includeID = includeID
		self.dirtyAttributesOnly = dirtyAttributesOnly
		self.includeToMany = includeToMany
		self.includeToOne = includeToOne
	}
}

struct DeserializationOptions {
	var mapOntoFirstResourceInStore = false
	
	init(mapOntoFirstResourceInStore: Bool = false) {
		self.mapOntoFirstResourceInStore = mapOntoFirstResourceInStore
	}
}


// MARK: - ResourceFactory

struct ResourceFactory {
	
	private var factoryFunctions: [String: () -> ResourceProtocol] = [:]

	mutating func registerResource(type: String, factory: () -> ResourceProtocol) {
		factoryFunctions[type] = factory
	}

	func instantiate(type: String) -> ResourceProtocol {
		assert(factoryFunctions[type] != nil, "Cannot instantiate resource of type \(type). You must register this type with Spine first.")
		return factoryFunctions[type]!()
	}

	subscript(type: String) -> ResourceProtocol {
		return instantiate(type)
	}
}