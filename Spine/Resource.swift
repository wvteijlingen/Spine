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
A base recource class that provides some defaults for resources.
You can create custom resource classes by subclassing from Resource.
*/
public class Resource: NSObject, NSCoding {
	public class var resourceType: ResourceType {
		fatalError("Override resourceType in a subclass.")
	}
	final public var resourceType: ResourceType { return self.dynamicType.resourceType }
	
	public class var fields: [Field] { return [] }
	final public var fields: [Field] { return self.dynamicType.fields }
	
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
	
	/// Sets all fields of resource `resource` to nil and sets `isLoaded` to false.
	public func unload() {
		for field in self.fields {
			self.setValue(nil, forField: field.name)
		}
		
		isLoaded = false
	}
}

extension Resource {
	override public var description: String {
		return "\(self.resourceType)(\(self.id), \(self.URL))"
	}
	
	override public var debugDescription: String {
		return description
	}
}

public func == <T: Resource> (left: T, right: T) -> Bool {
	return (left.id == right.id) && (left.resourceType == right.resourceType)
}