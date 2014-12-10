//
//  Mapping.swift
//  Spine
//
//  Created by Ward van Teijlingen on 23-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import UIKit
import SwiftyJSON

typealias DeserializationResult = (store: Store<Resource>?, pagination: PaginationData?, error: NSError?)

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
	mutating func registerClass(type: Resource.Type) {
		let instance = type()
		self.registeredClasses[instance.type] = type
	}
	
	/**
	 Unregister a Resource subclass. If the type was not prevously registered, nothing happens.
	 Example: `classMap.unregister(User.self)`

	 :param: type The Type of the subclass to unregister.
	 */
	mutating func unregisterClass(type: Resource.Type) {
		let instance = type()
		self.registeredClasses[instance.type] = nil
	}
	
	/**
	 Returns the Resource.Type into which a resource with the given type should be mapped.

	 :param: resourceType The resource type for which to return the matching class.

	 :returns: The Resource.Type that matches the given resource type.
	 */
	func classForResourceType(type: String) -> Resource.Type {
		return registeredClasses[type]!
	}
	
	/**
	 *  Returns the Resource.Type into which a resource with the given type should be mapped.
	 */
	subscript(type: String) -> Resource.Type {
		return self.classForResourceType(type)
	}
}

// MARK: -

/**
The serialization mode.

- AllAttributes:	Serialize all attributes including relationships.
- DirtyAttributes:	Serialize only dirty attributes and all relationships.
*/
public enum SerializationMode {
	case AllAttributes, DirtyAttributes
}

// MARK: -

protocol SerializerProtocol {
	// Class mapping
	func registerClass(type: Resource.Type)
	func unregisterClass(type: Resource.Type)
	func classNameForResourceType(resourceType: String) -> Resource.Type
	
	// Deserializing
	func deserializeData(data: NSData) -> DeserializationResult
	func deserializeData(data: NSData, usingStore store: Store<Resource>) -> DeserializationResult
	func deserializeError(data: NSData, withResonseStatus responseStatus: Int) -> NSError
	
	// Serializing
	func serializeResources(resources: [Resource], mode: SerializationMode) -> [String: AnyObject]
}

/**
 *  The serializer is responsible for serializing and deserialing resources.
 *  It stores information about the Resource classes using a ResourceClassMap
 *  and uses SerializationOperations and DeserialisationOperations for (de)serializing.
 */
class JSONAPISerializer: SerializerProtocol {

	/// The class map that holds information about resource type/class mapping.
	private var classMap: ResourceClassMap = ResourceClassMap()
	
	
	//MARK: Class mapping
	
	/**
	 Register a Resource subclass with this serializer.
	 Example: `classMap.register(User.self)`

	 :param: type The Type of the subclass to register.
	 */
	func registerClass(type: Resource.Type) {
		self.classMap.registerClass(type)
	}
	
	/**
	 Unregister a Resource subclass from this serializer. If the type was not prevously registered, nothing happens.
	 Example: `classMap.unregister(User.self)`

	 :param: type The Type of the subclass to unregister.
	 */
	func unregisterClass(type: Resource.Type) {
		self.classMap.unregisterClass(type)
	}
	
	/**
	 Returns the Resource.Type into which a resource with the given type should be mapped.

	 :param: resourceType The resource type for which to return the matching class.

	 :returns: The Resource.Type that matches the given resource type.
	 */
	func classNameForResourceType(resourceType: String) -> Resource.Type {
		return self.classMap[resourceType]
	}
	
	
	// MARK: Serializing

	/**
	 Deserializes the given data into a SerializationResult. This is a thin wrapper around
	 a DeserializeOperation that does the actual deserialization.

	 :param: data The data to deserialize.

	 :returns: A DeserializationResult that contains either a Store or an error.
	 */
	func deserializeData(data: NSData) -> DeserializationResult {
		let mappingOperation = DeserializeOperation(data: data, classMap: self.classMap)
		mappingOperation.start()
		return mappingOperation.result!
	}

	/**
	 Deserializes the given data into a SerializationResult. This is a thin wrapper around
	 a DeserializeOperation that does the actual deserialization.

	 Use this method if you want to deserialize onto existing Resource instances. Otherwise, use
	 the regular `deserializeData` method.

	 :param: data  The data to deserialize.
	 :param: store A Store that contains Resource instances onto which data will be deserialize.

	 :returns: A DeserializationResult that contains either a Store or an error.
	 */

	func deserializeData(data: NSData, usingStore store: Store<Resource>) -> DeserializationResult {
		let mappingOperation = DeserializeOperation(data: data, store: store, classMap: self.classMap)
		mappingOperation.start()
		return mappingOperation.result!
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
		
		return NSError(domain: SPINE_ERROR_DOMAIN, code: code, userInfo: userInfo)
	}

	/**
	 Serializes the given Resources into a multidimensional dictionary/array structure
	 that can be passed to NSJSONSerialization.

	 :param: resources The resources to serialize.
	 :param: mode      The serialization mode to use.

	 :returns: A multidimensional dictionary/array structure.
	 */
	func serializeResources(resources: [Resource], mode: SerializationMode) -> [String: AnyObject] {
		let mappingOperation = SerializeOperation(resources: resources, mode: mode)
		mappingOperation.start()
		return mappingOperation.result!
	}
}


// MARK: -

/**
 *  A DeserializeOperation is responsible for deserializing a single server response.
 *  The serialized data is converted into Resource instances using a layered process.
 *
 *  This process is the inverse of that of the SerializeOperation.
 */
class DeserializeOperation: NSOperation {
	
	// Input
	private var classMap: ResourceClassMap
	private var data: JSON
	
	// Output
	private var store: Store<Resource>
	private var paginationData: PaginationData?
	
	
	private lazy var formatter = {
		Formatter()
	}()
	
	var result: DeserializationResult?
	
	init(data: NSData, classMap: ResourceClassMap) {
		self.data = JSON(data: data)
		self.classMap = classMap
		self.store = Store()
		super.init()
	}
	
	init(data: NSData, store: Store<Resource>, classMap: ResourceClassMap) {
		self.data = JSON(data: data)
		self.classMap = classMap
		self.store = store
		super.init()
	}
	
	override func main() {
		// Check if the given data is in the expected format
		if (self.data.dictionary == nil) {
			let error = NSError(domain: SPINE_ERROR_DOMAIN, code: 0, userInfo: [NSLocalizedDescriptionKey: "The given JSON representation was not as expected."])
			self.result = DeserializationResult(nil, nil, error)
			return
		}
		
		// Extract link templates
		let linkTemplates: JSON? = self.data.dictionaryValue["links"]

		// Extract resources
		for(key: String, data: JSON) in self.data.dictionaryValue {
			// Linked resources for compound documents
			if key == "linked" {
				for (linkedResourceType, linkedResources) in data.dictionaryValue {
					for representation in linkedResources.array! {
						self.deserializeSingleRepresentation(representation, withResourceType: linkedResourceType, linkTemplates: linkTemplates)
					}
				}
			
			} else if key != "links" && key != "meta" {
				// Multiple resources
				if let representations = data.array {
					for representation in representations {
						self.deserializeSingleRepresentation(representation, withResourceType: key, linkTemplates: linkTemplates)
					}
					
				// Single resource
				} else {
					self.deserializeSingleRepresentation(data, withResourceType: key, linkTemplates: linkTemplates)
				}
			}
		}
		
		// Extract meta
		self.extractMeta()
		
		// Resolve relations in the store
		self.resolveRelations()
		
		// Create a result
		self.result = DeserializationResult(self.store, self.paginationData, nil)
	}

	/**
	Maps a single resource representation into a resource object of the given type.
	
	:param: representation The JSON representation of a single resource.
	:param: resourceType   The type of resource onto which to map the representation.
	*/
	private func deserializeSingleRepresentation(representation: JSON, withResourceType resourceType: String, linkTemplates: JSON? = nil) {
		assert(representation.dictionary != nil, "The given JSON representation was not of type 'object' (dictionary).")
		
		// Find existing resource in the store, or create a new resource.
		var resource: Resource
		var isExistingResource: Bool
		
		if let existingResource = self.store.objectWithType(resourceType, identifier: representation["id"].stringValue) {
			resource = existingResource
			isExistingResource = true
		} else if let existingResource = self.store.allObjectsWithType(resourceType).first {
			resource = existingResource
			isExistingResource = true
		} else {
			resource = self.classMap[resourceType]() as Resource
			isExistingResource = false
		}

		// Extract data into resource
		self.extractID(representation, intoResource: resource)
		self.extractHref(representation, intoResource: resource)
		self.extractAttributes(representation, intoResource: resource)
		self.extractRelationships(representation, intoResource: resource, linkTemplates: linkTemplates)

		// Add resource to store if needed
		if !isExistingResource {
			self.store.add(resource)
		}
	}
	
	
	// MARK: Special attributes
	
	/**
	 Extracts the resource ID from the serialized data into the given resource.

	 :param: serializedData The data from which to extract the ID.
	 :param: resource       The resource into which to extract the ID.
	 */
	private func extractID(serializedData: JSON, intoResource resource: Resource) {
		if serializedData["id"].stringValue != "" {
			resource.id = serializedData["id"].stringValue
		}
	}
	
	/**
	 Extracts the resource href from the serialized data into the given resource.

	 :param: serializedData The data from which to extract the href.
	 :param: resource       The resource into which to extract the href.
	 */
	private func extractHref(serializedData: JSON, intoResource resource: Resource) {
		if let href = serializedData["href"].string {
			resource.href = href
		}
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
	private func extractAttributes(serializedData: JSON, intoResource resource: Resource) {
		for (attributeName, attribute) in resource.persistentAttributes {
			if attribute.isRelationship() {
				continue
			}
			
			let key = attribute.representationName ?? attributeName
			
			if let extractedValue: AnyObject = self.extractAttribute(serializedData, key: key) {
				let formattedValue: AnyObject = self.formatter.deserialize(extractedValue, ofType: attribute.type)
				resource.setValue(formattedValue, forKey: attributeName)
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
	private func extractRelationships(serializedData: JSON, intoResource resource: Resource, linkTemplates: JSON? = nil) {
		for (attributeName, attribute) in resource.persistentAttributes {
			if !attribute.isRelationship() {
				continue
			}
			
			let key = attribute.representationName ?? attributeName
			
			switch attribute.type {
			case .ToOne:
				if let linkedResource = self.extractToOneRelationship(serializedData, key: key, resource: resource, linkTemplates: linkTemplates) {
					resource.setValue(linkedResource, forKey: attributeName)
				}
			case .ToMany:
				if let linkedResources = self.extractToManyRelationship(serializedData, key: key, resource: resource, linkTemplates: linkTemplates) {
					resource.setValue(linkedResources, forKey: attributeName)
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
	private func extractToOneRelationship(serializedData: JSON, key: String, resource: Resource, linkTemplates: JSON? = nil) -> LinkedResource? {
		// Resource level link with href/id/type combo
		if let linkData = serializedData["links"][key].dictionary {
			var href: NSURL?, type: String, ID: String?
			
			if let rawHref = linkData["href"]?.string {
				href = NSURL(string: rawHref)
			}
			
			if let rawType = linkData["type"]?.string {
				type = rawType
			} else {
				type = key + "s" // TODO: Retrieve type from ResourceAttribute
			}
			
			if linkData["id"]?.stringValue != "" {
				ID = linkData["id"]!.stringValue
			}
			
			return LinkedResource(href: href, type: type, id: ID)
		}
		
		// Resource level link with only an id
		let ID = serializedData["links"][key].stringValue
		if ID != "" {
			return LinkedResource(href: nil, type: key + "s", id: ID) // TODO: Retrieve type from ResourceAttribute
		}
		
		// Document level link template
		if let linkData = linkTemplates?[resource.type + "." + key].dictionary {
			var href: NSURL?, type: String
			
			if let hrefTemplate = linkData["href"]?.string {
				if let interpolatedHref = hrefTemplate.interpolate(serializedData.dictionaryObject! as NSDictionary, rootKeyPath: resource.type) {
					href = NSURL(string: interpolatedHref)
				} else {
					println("Error: Could not interpolate href template: \(hrefTemplate)")
				}
			}
			
			if let rawType = linkData["type"]?.string {
				type = rawType
			} else {
				type = key + "s"  // TODO: Retrieve type from ResourceAttribute
			}
			
			return LinkedResource(href: href, type: type)
		}
		
		return nil
	}
	
	/**
	 Extracts the to-many relationship for the given key from the passed serialized data.
	
	 This method supports both the array of IDs form and the resource object forms.
	
	 :param: serializedData The data from which to extract the relationship.
	 :param: key            The key for which to extract the relationship from the data.
	
	 :returns: The extracted relationship or nil if no relationship with the given key was found in the data.
	*/
	private func extractToManyRelationship(serializedData: JSON, key: String, resource: Resource, linkTemplates: JSON? = nil) -> ResourceCollection? {
		// Resource level link with href/id/type combo
		if let linkData = serializedData["links"][key].dictionary {
			var href: NSURL?, type: String, IDs: [String]?
			
			if let rawHref = linkData["href"]?.string {
				href = NSURL(string: rawHref)
			}
			
			if let rawIDs = linkData["ids"]?.array {
				IDs = rawIDs.map { $0.stringValue }
				IDs?.filter { $0 != "" }
			}
			
			if let rawType = linkData["type"]?.string {
				type = rawType
			} else {
				type = key
			}
		
			return ResourceCollection(href: href, type: type, ids: IDs)
		}
		
		// Resource level link with only ids
		if let rawIDs: [JSON] = serializedData["links"][key].array {
			let IDs = rawIDs.map { $0.stringValue }
			IDs.filter { return $0 != "" }
			return ResourceCollection(href: nil, type: key, ids: IDs)
		}

		// Document level link template
		if let linkData = linkTemplates?[resource.type + "." + key].dictionary {
			var href: NSURL?, type: String, IDs: [String]?
			
			if let hrefTemplate = linkData["href"]?.string {
				if let interpolatedHref = hrefTemplate.interpolate(serializedData.dictionaryObject! as NSDictionary, rootKeyPath: resource.type) {
					href = NSURL(string: interpolatedHref)
				} else {
					println("Error: Could not interpolate href template: \(hrefTemplate)")
				}
			}
			
			if let rawType = linkData["type"]?.string {
				type = rawType
			} else {
				type = key
			}
			
			if let rawIDs = serializedData["links"][key].array {
				IDs = rawIDs.map { return $0.stringValue }
				IDs?.filter { return $0 != "" }
			}
			
			return ResourceCollection(href: href, type: type, ids: IDs)
		}
		
		return nil
	}
	
	/**
	 Resolves the relations of the resources in the store.
	*/
	private func resolveRelations() {
		for resource in self.store {
			
			for (attributeName, attribute) in resource.persistentAttributes {
				if !attribute.isRelationship() {
					continue
				}
				
				if attribute.type == .ToOne {
					if let linkedResource = resource.valueForKey(attributeName) as? LinkedResource {
						
						// We can only resolve if an ID is known
						if let id = linkedResource.link?.id {
							// Find target of relation in store
							if let targetResource = store.objectWithType(linkedResource.link!.type, identifier: id) {
								linkedResource.fulfill(targetResource)
							}
						} else {
							println("Cannot resolve to-one link '\(attributeName)' because the foreign ID is not known or the related resource was not included.")
						}
					} else {
						println("Cannot resolve to-one link '\(attributeName)' because the link data is not fetched.")
					}
					
				} else if attribute.type == .ToMany {
					if let linkedResource = resource.valueForKey(attributeName) as? ResourceCollection {
						var targetResources: [Resource] = []
						
						// We can only resolve if IDs are known
						if let ids = linkedResource.link?.ids {
							
							for id in ids {
								// Find target of relation in store
								if let targetResource = store.objectWithType(linkedResource.link!.type, identifier: id) {
									targetResources.append(targetResource)
								}
							}
							
							linkedResource.fulfill(targetResources)
						} else {
							println("Cannot resolve to-many link '\(attributeName)' because the foreign IDs are not known or the related resources were not included.")
						}
					} else {
						println("Cannot resolve to-many link '\(attributeName)' because the link data is not fetched.")
					}
				}
			}
		}
	}
	
	
	// MARK: Meta
	
	private func extractMeta() {
		if let meta = self.data["meta"].dictionary {
			var paginationData = PaginationData(
				count: meta["count"]?.int,
				limit: meta["limit"]?.int,
				beforeCursor: meta["before_cursor"]?.string,
				afterCursor: meta["after_cursor"]?.string,
				nextHref: nil,
				previousHref: nil
			)

			if let nextHref = meta["after_cursor"]?.string {
				paginationData.nextHref = NSURL(string: nextHref)
			}
			
			if let previousHref = meta["previous_cursor"]?.string {
				paginationData.previousHref = NSURL(string: previousHref)
			}
			
			self.paginationData = paginationData
		}
	}
}


// MARK: -

/**
 *  A SerializeOperation is responsible for serializing resource into a multidimensional dictionary/array structure.
 *  The resouces are converted to their serialized form using a layered process.
 *
 *  This process is the inverse of that of the DeserializeOperation.
 */
class SerializeOperation: NSOperation {
	
	private let resources: [Resource]
	private let formatter = Formatter()
	private let mode: SerializationMode
	
	var result: [String: AnyObject]?
	
	init(resources: [Resource], mode: SerializationMode) {
		self.resources = resources
		self.mode = mode
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
		for (attributeName, attribute) in resource.persistentAttributes {
			if attribute.isRelationship() {
				continue
			}

			//TODO: Dirty checking
			
			let key = attribute.representationName ?? attributeName
			
			if let unformattedValue: AnyObject = resource.valueForKey(attributeName) {
				self.addAttribute(&serializedData, key: key, value: self.formatter.serialize(unformattedValue, ofType: attribute.type))
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
		for (attributeName, attribute) in resource.persistentAttributes {
			if !attribute.isRelationship() {
				continue
			}
			
			let key = attribute.representationName ?? attributeName

			switch attribute.type {
				case .ToOne:
					self.addToOneRelationship(&serializedData, key: key, relatedResource: resource.valueForKey(attributeName) as? Resource)
				case .ToMany:
					self.addToManyRelationship(&serializedData, key: key, relatedResources: resource.valueForKey(attributeName) as? [Resource])
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
	private func addToOneRelationship(inout serializedData: [String: AnyObject], key: String, relatedResource: Resource?) {
		var linkData: AnyObject
		
		if let ID = relatedResource?.id {
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
	private func addToManyRelationship(inout serializedData: [String: AnyObject], key: String, relatedResources: [Resource]?) {
		var linkData: AnyObject
		
		if let resources = relatedResources {
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


// MARK: -

class Formatter {

	private func deserialize(value: AnyObject, ofType type: ResourceAttribute.AttributeType) -> AnyObject {
		switch type {
		case .Date:
			return self.deserializeDate(value as String)
		default:
			return value
		}
	}
	
	private func serialize(value: AnyObject, ofType type: ResourceAttribute.AttributeType) -> AnyObject {
		switch type {
		case .Date:
			return self.serializeDate(value as NSDate)
		default:
			return value
		}
	}
	
	// MARK: Date
	
	private lazy var dateFormatter: NSDateFormatter = {
		let formatter = NSDateFormatter()
		formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
		return formatter
	}()

	private func serializeDate(date: NSDate) -> String {
		return self.dateFormatter.stringFromDate(date)
	}

	private func deserializeDate(value: String) -> NSDate {
		if let date = self.dateFormatter.dateFromString(value) {
			return date
		}
		
		return NSDate()
	}
}


// MARK: -

extension String {
	func interpolate(callback: (key: String) -> String?) -> String {
		var interpolatedString = ""
		let scanner = NSScanner(string: self)
		
		while(scanner.atEnd == false) {
			var scannedPart: NSString?
			var scannedKey: NSString?
			
			scanner.scanUpToString("{", intoString: &scannedPart)
			scanner.scanString("{", intoString: nil)
			scanner.scanUpToString("}", intoString: &scannedKey)
			
			if let part = scannedPart {
				interpolatedString = interpolatedString + part
			}
			
			if let key = scannedKey {
				if let value = callback(key: key) {
					interpolatedString = interpolatedString + value
				}
				scanner.scanString("}", intoString: nil)
			}
		}
		
		return interpolatedString
	}
	
	func interpolate(values: NSObject, rootKeyPath: String? = nil) -> String? {
		let fallbackPrefix = "links"
		let fallbackPostfix = "id"
		
		func formatValue(value: AnyObject?) -> String? {
			if value == nil {
				return nil
			}
			
			switch value {
			case let stringValue as String:
				return stringValue
			case let intValue as Int:
				return "\(intValue)"
			case let doubleValue as Double:
				return "\(doubleValue)"
			case let stringArrayValue as [String]:
				return ",".join(stringArrayValue)
			default:
				return nil
			}
		}
		
		return self.interpolate { key in
			var keyPath = key
			
			if let prefix = rootKeyPath {
				if keyPath.hasPrefix(prefix) {
					let stringToRemove = prefix + "."
					keyPath = keyPath.substringFromIndex(stringToRemove.endIndex)
				}
			}
			
			if let value1 = formatValue(values.valueForKeyPath(keyPath)) {
				return value1
			} else if let value2 = formatValue(values.valueForKeyPath("\(keyPath).\(fallbackPostfix)")) {
				return value2
			} else if let value3 = formatValue(values.valueForKeyPath("\(fallbackPrefix).\(keyPath)")) {
				return value3
			}
			
			return nil
		}
	}
}