//
//  Resource.swift
//  Spine
//
//  Created by Ward van Teijlingen on 25-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation

public typealias ResourceType = String

/**
A ResourceIdentifier uniquely identifies a resource that exists on the server.
*/
public struct ResourceIdentifier: Equatable {
	var type: ResourceType
	var id: String
	
	init(type: ResourceType, id: String) {
		self.type = type
		self.id = id
	}
	
	init(dictionary: NSDictionary) {
		type = dictionary["type"] as! ResourceType
		id = dictionary["id"] as! String
	}
	
	func toDictionary() -> NSDictionary {
		return ["type": type, "id": id]
	}
}

public func ==(lhs: ResourceIdentifier, rhs: ResourceIdentifier) -> Bool {
	return lhs.type == rhs.type && lhs.id == rhs.id
}

/**
The Resource declares methods and properties that a resource must implement.
*/
protocol ResourceProtocol: class {
	/// The resource type in plural form.
	static var resourceType: ResourceType { get }
	
	/// The resource type in plural form.
	var type: ResourceType { get }
	
	/// All fields that must be persisted in the API.
	static var fields: [Field] { get }
	
	/// The ID of the resource.
	var id: String? { get set }
	
	/// The self URL of the resource.
	var URL: NSURL? { get set }
	
	/// Whether the fields of the resource are loaded.
	var isLoaded: Bool { get set }
	
	/**
	Returns the attribute value for the given key
	
	:param: field The name of the field to get the value for.
	
	:returns: The value of the field.
	*/
	func valueForField(field: String) -> AnyObject?
	
	/**
	Sets the given attribute value for the given key.
	
	:param: value    The value to set.
	:param: forField The name of the field to set the value for.
	*/
	func setValue(value: AnyObject?, forField: String)
}

public protocol MetaHoldable: class {
	var meta: [String: AnyObject]? { get set }
}

/**
A base recource class that provides some defaults for resources.
You can create custom resource classes by subclassing from Resource.
*/
public class Resource: NSObject, NSCoding, ResourceProtocol, MetaHoldable {
	public class var resourceType: ResourceType {
		fatalError("Override resourceType in a subclass.")
	}
	
	public var type: ResourceType {
		return self.dynamicType.resourceType
	}
	
	public class var fields: [Field] { return [] }
	public var id: String?
	public var URL: NSURL?
	public var isLoaded: Bool = false
	public var meta: [String: AnyObject]?
	
	public override init() {}
	
	public required init(coder: NSCoder) {
		super.init()
		self.id = coder.decodeObjectForKey("id") as? String
		self.URL = coder.decodeObjectForKey("URL") as? NSURL
		self.isLoaded = coder.decodeBoolForKey("isLoaded")
	}
	
	public func encodeWithCoder(coder: NSCoder) {
		coder.encodeObject(self.id, forKey: "id")
		coder.encodeObject(self.URL, forKey: "URL")
		coder.encodeBool(self.isLoaded, forKey: "isLoaded")
	}
	
	public func valueForField(field: String) -> AnyObject? {
		return valueForKey(field)
	}
	
	public func setValue(value: AnyObject?, forField field: String) {
		setValue(value, forKey: field)
	}
}

extension Resource {
	override public var description: String {
		return "\(self.type)(\(self.id), \(self.URL))"
	}
	
	override public var debugDescription: String {
		return description
	}
}