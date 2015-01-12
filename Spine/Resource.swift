//
//  Resource.swift
//  Spine
//
//  Created by Ward van Teijlingen on 25-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation
import BrightFutures

@objc public protocol ResourceProtocol: class {
    class var resourceType: String { get }
    var type: String { get }
    
    var attributes: [Attribute] { get }
    
    var id: String? { get set }
    var href: NSURL? { get set }
    var isLoaded: Bool { get set }
	
	subscript(key: String) -> AnyObject? { get set }
}


/**
*  A base recource class that provides some defaults for resources.
*  You must create custom resource classes by subclassing from Resource.
*/
public class Resource: NSObject, ResourceProtocol, NSCoding, Printable {
	public class var resourceType: String { return "_unknown_type" }
    public var type: String { return self.dynamicType.resourceType }
    
	public var id: String?
	public var href: NSURL?
	public var isLoaded: Bool = false
	
	
	public override init() {}
	
	
	// MARK: NSCoding protocol
	
	public required init(coder: NSCoder) {
		super.init()
		self.id = coder.decodeObjectForKey("id") as? String
		self.href = coder.decodeObjectForKey("href") as? NSURL
		self.isLoaded = coder.decodeBoolForKey("isLoaded")

	}
	
	public func encodeWithCoder(coder: NSCoder) {
		coder.encodeObject(self.id, forKey: "id")
		coder.encodeObject(self.href, forKey: "href")
		coder.encodeBool(self.isLoaded, forKey: "isLoaded")
	}
	
	
	// MARK: Mapping data
	
	/// Array of attributes that must be mapped by Spine.
	public var persistentAttributes: [String: Attribute] {
		return [:]
	}
	
	public var attributes: [Attribute] {
		return map(self.persistentAttributes) { (name, attribute) in
			attribute.name = name
			return attribute
		}
	}
	
    public subscript(key: String) -> AnyObject? {
        get {
           return valueForKey(key)
        }
        set {
            setValue(newValue, forKey: key)
        }
    }
	
	// MARK: Persisting
	
	/**
	Saves this resource asynchronously.
	
	:returns: A future of this resource.
	*/
	public func save() -> Future<ResourceProtocol> {
		return Spine.sharedInstance.save(self)
	}
	
	/**
	Deletes this resource asynchronously.
	
	:returns: A void future.
	*/
	public func delete() -> Future<Void> {
		return Spine.sharedInstance.delete(self)
	}
	
	
	// MARK: Printable protocol
	
	override public var description: String {
		return "\(self.type)[\(self.id)]"
	}
}