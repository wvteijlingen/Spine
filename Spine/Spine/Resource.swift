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
 *  A base recource class that provides some defaults for resources.
 *  You must create custom resource classes by subclassing from Resource.
 */
public class Resource: NSObject, Printable {

	/// The unique identifier of this resource. If this is nil, the resource hasn't been saved yet.
	public var resourceID: String?

	/// The type of this resource in plural form. For example: 'posts', 'users'.
	public var resourceType: String { return "_undefined" }

	/// The location (URL) of this resource.
	public var resourceLocation: String?

	/// Links to other resources.
	public var relationships: [String: ResourceRelationship] = [:]

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
	public func saveInBackground() {
		Spine.sharedInstance.saveResource(self, success: {}, failure: {(error) in })
	}

	public func deleteInBackground() {
		Spine.sharedInstance.deleteResource(self, success: {}, failure: {(error) in })
	}

	public class func findOne(ID: String, success: (Resource) -> Void, failure: (NSError) -> Void) {
		let instance = self()
		Spine.sharedInstance.fetchResourceWithType(instance.resourceType, ID: ID, success: success, failure: failure)
	}

	public class func find(IDs: [String], success: ([Resource]) -> Void, failure: (NSError) -> Void) {
		let instance = self()
		let query = Query(resourceType: instance.resourceType, resourceIDs: IDs)
		Spine.sharedInstance.fetchResourcesForQuery(query, success, failure)
	}

	public class func findAll(success: ([Resource]) -> Void, failure: (NSError) -> Void) {
		let instance = self()
		let query = Query(resourceType: instance.resourceType)
		Spine.sharedInstance.fetchResourcesForQuery(query, success, failure)
	}
}