//
//  Resource.swift
//  Spine
//
//  Created by Ward van Teijlingen on 25-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation

@objc public protocol ResourceProtocol: class {
	/// The resource type in plural form.
    class var resourceType: String { get }
	
	/// The resource type in plural form.
    var type: String { get }
	
	/// All fields that must be persisted in the API.
    var fields: [Field] { get }
	
	/// The ID of the resource.
    var id: String? { get set }
	
	/// The self URL of the resource.
    var URL: NSURL? { get set }
	
	/// Whether the attributes of the resource are loaded.
    var isLoaded: Bool { get set }
	
	/// Returns the attribute value for the given key
	func valueForField(field: String) -> AnyObject?
	
	/// Sets the given attribute value for the given key
	func setValue(value: AnyObject?, forField: String)
}

/**
 *  A base recource class that provides some defaults for resources.
 *  You can create custom resource classes by subclassing from Resource.
 */
public class Resource: NSObject, NSCoding, ResourceProtocol {
	public class var resourceType: String {
		fatalError("Override resourceType in a subclass.")
	}
	
    public var type: String {
		return self.dynamicType.resourceType
	}
	
	public var fields: [Field] {
		return []
	}
	
	public var id: String?
	public var URL: NSURL?
	public var isLoaded: Bool = false
	
	public override init() {
		
	}
	
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

extension Resource: Printable, DebugPrintable {
	override public var description: String {
		return "\(self.type)(\(self.id), \(self.URL))"
	}
	
	override public var debugDescription: String {
		return description
	}
}