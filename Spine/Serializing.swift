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
	var resourceTypes: ResourceClassMap { get }
	var transformers: TransformerDirectory { get }
	
	// Deserializing
	func deserializeData(data: NSData, usingStore store: Store, options: DeserializationOptions) -> DeserializationResult
	func deserializeError(data: NSData, withResonseStatus responseStatus: Int) -> NSError
	
	// Serializing
	func serializeResources(resources: [Resource], options: SerializationOptions) -> [String: AnyObject]
}

/**
*  The serializer is responsible for serializing and deserialing resources.
*  It stores information about the Resource classes using a ResourceClassMap
*  and uses SerializationOperations and DeserialisationOperations for (de)serializing.
*/
class JSONSerializer: SerializerProtocol {
	
	/// The class map that holds information about resource type/class mapping.
	var resourceTypes = ResourceClassMap()
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
		store.classMap = resourceTypes
		
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
	func serializeResources(resources: [Resource], options: SerializationOptions = SerializationOptions()) -> [String: AnyObject] {
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


// MARK: - Class map

/**
*  A ResourceClassMap contains information about how resource types
*  should be mapped to Resource classes.

*  Each resource type is mapped to one specific Resource subclass.
*/
struct ResourceClassMap {
	
	/// The registered resource type/class pairs.
	private var registeredClasses: [String: Resource.Type] = [:]
	
	/**
	Register a Resource subclass.
	Example: `classMap.register(User.self)`
	
	:param: type The Type of the subclass to register.
	*/
	mutating func registerResource(type: Resource.Type) {
		assert(registeredClasses[type.type] == nil, "Cannot register class of type \(type). A class with that type is already registered.")
		self.registeredClasses[type.type] = type
	}
	
	/**
	Unregister a Resource subclass. If the type was not prevously registered, nothing happens.
	Example: `classMap.unregister(User.self)`
	
	:param: type The Type of the subclass to unregister.
	*/
	mutating func unregisterResource(type: Resource.Type) {
		assert(registeredClasses[type.type] != nil, "Cannot unregister class of type \(type). Type does not exist in the class map.")
		self.registeredClasses[type.type] = nil
	}
	
	/**
	Returns the Resource.Type into which a resource with the given type should be mapped.
	
	:param: resourceType The resource type for which to return the matching class.
	
	:returns: The Resource.Type that matches the given resource type.
	*/
	func classForResourceType(type: String) -> Resource.Type {
		assert(registeredClasses[type] != nil, "Cannot map resources of type \(type). You must create a Resource subclass and register it with Spine.")
		return registeredClasses[type]!
	}
	
	/**
	*  Returns the Resource.Type into which a resource with the given type should be mapped.
	*/
	subscript(type: String) -> Resource.Type {
		return self.classForResourceType(type)
	}
}