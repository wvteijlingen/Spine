//
//  Resource.swift
//  Spine
//
//  Created by Ward van Teijlingen on 25-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation

/**
Represents a resource attribute that can be persisted to the server.

- Property: The attribute is a plain property.
- ToOne:    The attribute is a to-one relationship.
- ToMany:   The attribute is a to-many relationship.
*/
public enum ResourceAttribute {
	case Property, Date, ToOne, ToMany
}

/**
Represents a relationship to another resource or resources.

- ToOne:  A to-one relationship.
- ToMany: A to-many relationship.
*/
public enum ResourceRelationship {
	case ToOne(href: String, ID: String, type: String)
	case ToMany(href: String, IDs: [String], type: String)
}

/**
 *  The protocol that all resource classes must implement.
 *  You can implement this protocol yourself or use the Resource class as base for your custom classes.
 */
public protocol ResourceClass {
	/// The unique identifier of this resource
	var resourceID: String? { get set }
	
	/// The resource type of this resource. Must be plural.
	var resourceType: String { get }
	
	/// The location (URL) of this resource.
	var resourceLocation: String? { get set }
	
	/// Links to other resources.
	var relationships: [String: ResourceRelationship] { get set }
	
	/// Array of attributes that must be mapped by Spine.
	var persistentAttributes: [String: ResourceAttribute] { get }
	
	func setValue(value: AnyObject, forAttribute attribute: String)
	func valueForAttribute(attribute: String) -> AnyObject!
}


/**
 *  A base recource class that provides some defaults for the variables and functions in the ResourceClass protocol.
 *  You can create custom classes by subclassing from Resource, or you can implement the ResourceClass yourself.
 */
public class Resource: NSObject, ResourceClass, Printable {
	
	// Identification properties
	public var resourceID: String?
	public var resourceType: String { return "_undefined" }
	public var resourceLocation: String?

	// Relationships
	public var relationships: [String: ResourceRelationship] = [:]

	// Mapping configuration
	public var persistentAttributes: [String: ResourceAttribute] { return [:] }
	
	required override public init() {
		// This is needed for the dynamic instantiation based on the metatype
	}
	
	public init(resourceID: String) {
		self.resourceID = resourceID
	}

	public func setValue(value: AnyObject, forAttribute attribute: String) {
		super.setValue(value, forKey: attribute)
	}
	
	public func valueForAttribute(attribute: String) -> AnyObject! {
		return super.valueForKey(attribute)
	}
	
	// Printable
	override public var description: String {
		return "\(self.resourceType)[\(self.resourceID)]"
	}
}