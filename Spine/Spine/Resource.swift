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

- Property: The attribute is a plain property
- ToOne:    The attribute is a to-one relationship
- ToMany:   The attribute is a to-many relationship
*/
public enum ResourceAttribute {
	case Property, Date, ToOne, ToMany
}

public enum ResourceRelation {
	case ToOne(href: String, ID: String, type: String)
	case ToMany(href: String, IDs: [String], type: String)
}

public class Resource: NSObject, Printable {
	
	// Identification properties
	public var resourceID: String?
	public var resourceType: String { return "_undefined" }
	public var resourceLocation: String?

	// Relationships
	public var relationships: [String: ResourceRelation] = [:]

	// Mapping configuration
	public var persistentAttributes: [String: ResourceAttribute] { return [:] }
	
	required override public init() {
		// This is needed for the dynamic instantiation based on the metatype
	}
	
	public init(resourceID: String) {
		self.resourceID = resourceID
	}

	
	// Printable
	override public var description: String {
		return "\(self.resourceType)[\(self.resourceID)]"
	}
}