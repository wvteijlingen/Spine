//
//  Resource.swift
//  Spine
//
//  Created by Ward van Teijlingen on 25-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation

public typealias ResourceType = String

/// A ResourceIdentifier uniquely identifies a resource that exists on the server.
public struct ResourceIdentifier: Equatable {
	/// The resource type.
	var type: ResourceType
	
	/// The resource ID.
	var id: String

	/// Constructs a new ResourceIdentifier instance with given `type` and `id`.
	init(type: ResourceType, id: String) {
		self.type = type
		self.id = id
	}

	/// Constructs a new ResourceIdentifier instance from the given dictionary.
	/// The dictionary must contain values for the "type" and "id" keys.
	init(dictionary: NSDictionary) {
		type = dictionary["type"] as! ResourceType
		id = dictionary["id"] as! String
	}

	/// Returns a dictionary with "type" and "id" keys containing the type and id.
	func toDictionary() -> NSDictionary {
		return ["type": type, "id": id]
	}
}

public func ==(lhs: ResourceIdentifier, rhs: ResourceIdentifier) -> Bool {
	return lhs.type == rhs.type && lhs.id == rhs.id
}

/// A RelationshipData struct holds data about a relationship.
struct RelationshipData {
	var selfURL: URL?
	var relatedURL: URL?
	var data: [ResourceIdentifier]?
	
	init(selfURL: URL?, relatedURL: URL?, data: [ResourceIdentifier]?) {
		self.selfURL = selfURL
		self.relatedURL = relatedURL
		self.data = data
	}
	
	/// Constructs a new ResourceIdentifier instance from the given dictionary.
	/// The dictionary must contain values for the "type" and "id" keys.
	init(dictionary: NSDictionary) {
		selfURL = dictionary["selfURL"] as? URL
		relatedURL = dictionary["relatedURL"] as? URL
		data = (dictionary["data"] as? [NSDictionary])?.map(ResourceIdentifier.init)
	}
	
	/// Returns a dictionary with "type" and "id" keys containing the type and id.
	func toDictionary() -> NSDictionary {
		var dictionary = [String: Any]()
		if let selfURL = selfURL {
			dictionary["selfURL"] = selfURL as AnyObject?
		}
		if let relatedURL = relatedURL {
			dictionary["relatedURL"] = relatedURL as AnyObject?
		}
		if let data = data {
			dictionary["data"] = data.map { $0.toDictionary() }
		}
		return dictionary as NSDictionary
	}
}

/// A base recource class that provides some defaults for resources.
/// You can create custom resource classes by subclassing from Resource.
open class Resource: NSObject, NSCoding {
	/// The resource type in plural form.
	open class var resourceType: ResourceType {
		fatalError("Override resourceType in a subclass.")
	}

	/// All fields that must be persisted in the API.
	open class var fields: [Field] { return [] }
	
	/// The ID of this resource.
	public var id: String?
	
	/// The canonical URL of the resource.
	public var url: URL?
	
	/// Whether the fields of the resource are loaded.
	public var isLoaded: Bool = false
	
	/// The metadata for this resource.
	public var meta: [String: Any]?
	
	/// Raw relationship data keyed by relationship name.
	var relationships: [String: RelationshipData] = [:]
	
	public required override init() {
		super.init()
	}
	
	public required init(coder: NSCoder) {
		super.init()
		self.id = coder.decodeObject(forKey: "id") as? String
		self.url = coder.decodeObject(forKey: "url") as? URL
		self.isLoaded = coder.decodeBool(forKey: "isLoaded")
		self.meta = coder.decodeObject(forKey: "meta") as? [String: AnyObject]
		
		if let relationshipsData = coder.decodeObject(forKey: "relationships") as? [String: NSDictionary] {
			var relationships = [String: RelationshipData]()
			for (key, value) in relationshipsData {
				relationships[key] = RelationshipData.init(dictionary: value)
			}
		}
	}
	
	open func encode(with coder: NSCoder) {
		coder.encode(id, forKey: "id")
		coder.encode(url, forKey: "url")
		coder.encode(isLoaded, forKey: "isLoaded")
		coder.encode(meta, forKey: "meta")
		
		var relationshipsData = [String: NSDictionary]()
		for (key, value) in relationships {
			relationshipsData[key] = value.toDictionary()
		}
		coder.encode(relationshipsData, forKey: "relationships")
	}

  /// Returns the value for the field named `field`.
	func value(forField field: String) -> Any? {
		return value(forKey: field) as AnyObject?
	}

	/// Sets the value for the field named `field` to `value`.
	func setValue(_ value: Any?, forField field: String) {
		setValue(value, forKey: field)
	}

	/// Set the values for all fields to nil and sets `isLoaded` to false.
	public func unload() {
		for field in fields {
			setValue(nil, forField: field.name)
		}
		
		isLoaded = false
	}
	
	/// Returns the field named `name`, or nil if no such field exists.
	class func field(named name: String) -> Field? {
		return fields.filter { $0.name == name }.first
	}
}

extension Resource {
	override open var description: String {
		return "\(resourceType)(\(id), \(url))"
	}
	
	override open var debugDescription: String {
		return description
	}
}

/// Instance counterparts of class functions
extension Resource {
	final var resourceType: ResourceType { return type(of: self).resourceType }
	final var fields: [Field] { return type(of: self).fields }
}

public func == <T: Resource> (left: T, right: T) -> Bool {
	return (left.id == right.id) && (left.resourceType == right.resourceType)
}
