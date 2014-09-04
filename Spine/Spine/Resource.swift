//
//  Resource.swift
//  Spine
//
//  Created by Ward van Teijlingen on 25-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation
import BrightFutures

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
enum ResourceRelationship {
	case ToOne(href: String, ID: String, type: String)
	case ToMany(href: String, IDs: [String], type: String)
}

/**
 *  A base recource class that provides some defaults for resources.
 *  You must create custom resource classes by subclassing from Resource.
 */
public class Resource: NSObject, Printable {

	/// The unique identifier of this resource. If this is nil, the resource hasn't been saved yet.
	public var resourceID: String?

	/// The type of this resource in plural form. For example: 'posts', 'users'.
	public var resourceType: String { return "_undefined" }

	/// The location (URL) of this resource.
	var resourceLocation: String?

	/// Links to other resources.
	var relationships: [String: ResourceRelationship] = [:]

	/// Array of attributes that must be mapped by Spine.
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

// MARK: - Convenience functions
extension Resource {
	public func saveInBackground() -> Future<Resource> {
		return Spine.sharedInstance.saveResource(self)
	}

	public func deleteInBackground() {
		Spine.sharedInstance.deleteResource(self, success: {}, failure: {(error) in })
	}

	public class func findOne(ID: String) -> Future<Resource> {
		let instance = self()
		return Spine.sharedInstance.fetchResourceWithType(instance.resourceType, ID: ID)
	}

	public class func find(IDs: [String]) -> Future<[Resource]> {
		let instance = self()
		let query = Query(resourceType: instance.resourceType, resourceIDs: IDs)
		return Spine.sharedInstance.fetchResourcesForQuery(query)
	}

	public class func findAll() -> Future<[Resource]> {
		let instance = self()
		let query = Query(resourceType: instance.resourceType)
		return Spine.sharedInstance.fetchResourcesForQuery(query)
	}
}