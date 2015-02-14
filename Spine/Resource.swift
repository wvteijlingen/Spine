//
//  Resource.swift
//  Spine
//
//  Created by Ward van Teijlingen on 25-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation
import BrightFutures

@objc public protocol Linkable {
	var URL: NSURL? { get set }
}

@objc public protocol ResourceProtocol: class, Linkable {
    class var resourceType: String { get }
    var type: String { get }
    
    var attributes: [Attribute] { get }
    
    var id: String? { get set }
    var URL: NSURL? { get set }
    var isLoaded: Bool { get set }
	
	func valueForAttribute(attribute: String) -> AnyObject?
	func setValue(value: AnyObject?, forAttribute: String)
}

/**
 *  A base recource class that provides some defaults for resources.
 *  You can create custom resource classes by subclassing from Resource.
 */
public class Resource: NSObject, NSCoding, ResourceProtocol {
	public class var resourceType: String {
		fatalError("Override resourceType in a subclass.")
	}
    public var type: String { return self.dynamicType.resourceType }
    
	public var id: String?
	public var URL: NSURL?
	public var isLoaded: Bool = false
	
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
	
	public func valueForAttribute(attribute: String) -> AnyObject? {
		return valueForKey(attribute)
	}
	
	public func setValue(value: AnyObject?, forAttribute attribute: String) {
		setValue(value, forKey: attribute)
	}
	
	/// Array of attributes that must be mapped by Spine.
	public var attributes: [Attribute] {
		return []
	}
}

extension Resource: Printable {
	override public var description: String {
		return "\(self.type)[\(self.id)]"
	}
}