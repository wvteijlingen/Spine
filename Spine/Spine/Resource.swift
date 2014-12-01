//
//  Resource.swift
//  Spine
//
//  Created by Ward van Teijlingen on 25-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation
import BrightFutures


//MARK: - Protocols

/**
*  An identifier that uniquely identifies a resource.
*
*  @param type The resource type in plural form.
*  @param id   The id of the resource. This must be unique amongst its type.
*/
public typealias ResourceIdentifier = (type: String, id: String)

protocol Identifiable {
	/// The resource id. If this is nil, the resource hasn't been saved yet.
	var id: String? { get set }
	
	/// The resource type in plural form.
	var type: String { get }
	
	/// The resource's unique identifier. If this is nil, the resource cannot be uniqually identified.
	var uniqueIdentifier: ResourceIdentifier? { get }
	
	/// The location (URL) of this resource.
	var href: String? { get set }
}

protocol Mappable {
	/// Array of attributes that must be mapped by Spine.
	var persistentAttributes: [String: ResourceAttribute] { get }
}

protocol Paginatable2 {
	var beforeCursor: String? { get set }
	var afterCursor: String? { get set }
	var pageSize: Int? { get set }
	var canFetchNextPage: Bool { get }
	var canFetchPreviousPage: Bool { get }
	func fetchNextPage()
	func fetchPreviousPage()
}


// MARK: - Base resource

/**
*  A base recource class that provides some defaults for resources.
*  You must create custom resource classes by subclassing from Resource.
*/
public class Resource: NSObject, Identifiable, Printable {
	
	// MARK: Initializers
	
	// This is needed for the dynamic instantiation based on the metatype
	required override public init() {
		super.init()
	}
	
	public init(id: String) {
		super.init()
		self.id = id
	}
	
	
	// MARK: Mappable protocol
	
	public var persistentAttributes: [String: ResourceAttribute] {
		return [:]
	}
	
	
	// MARK: Identifiable protocol
	
	private var _id: String?
	public var id: String? {
		get {
			return self._id
		}
		set (newValue) {
			self._id = newValue
		}
	}
	
	private var _href: String?
	public var href: String? {
		get {
			return self._href
		}
		set (newValue) {
			self._href = newValue
		}
	}
	
	public var type: String {
		return "_unknown_type"
	}
	
	public var uniqueIdentifier: ResourceIdentifier? {
		get {
			if let id = self.id {
				return (type: self.type, id: id)
			}
			
			return nil
		}
	}
	
	
	// MARK: Printable protocol
	
	override public var description: String {
		return "\(self.type)[\(self.id)]"
	}
}


//MARK: -

/**
 *  Describes a resource attribute that can be persisted to the server.
 */
public struct ResourceAttribute {
	
	/**
	The type of attribute.
	
	- Property: A plain property.
	- Date:     A formatted date property.
	- ToOne:    A to-one relationship.
	- ToMany:   A to-many relationship.
	*/
	public enum AttributeType {
		case Property, Date, ToOne, ToMany
	}
	
	/// The type of attribute.
	var type: AttributeType
	
	/// The name of the attribute in the JSON representation.
	/// This can be empty, in which case the same name as the attribute is used.
	var representationName: String?
	
	public init(type: AttributeType) {
		self.type = type
	}
	
	public init(type: AttributeType, representationName: String) {
		self.type = type
		self.representationName = representationName
	}
	
	func isRelationship() -> Bool {
		return (self.type == .ToOne || self.type == .ToMany)
	}
}


//MARK: -

public class LinkedResource: NSObject, Printable {
	public var isLoaded: Bool
	public var link: (href: NSURL, type: String, id: String?)?
	public var resource: Resource?
	
	// MARK: Initializers
	
	init(href: NSURL, type: String, id: String? = nil) {
		self.link = (href, type, id)
		self.isLoaded = false
	}
	
	init(href: NSURL) {
		if let type = href.pathComponents.last as? String {
			self.link = (href, type, nil)
			self.isLoaded = false
		} else {
			assertionFailure("The type could not be inferred from the given URL.")
		}
	}
	
	init(_ resource: Resource) {
		self.resource = resource
		self.isLoaded = true
	}
	
	// MARK: Printable
	
	override public var description: String {
		if self.isLoaded {
			if let resource = self.resource {
				return resource.description
			} else {
				return "(unidentifiable resource)"
			}
		} else {
			return self.link!.href.absoluteString!
		}
	}
	
	// MARK: Mutators
	
	public func fulfill(resource: Resource) {
		self.resource = resource
		self.isLoaded = true
	}
	
	// MARK: Fetching
	
	public func ensureResource() -> Future<(Resource)> {
		let promise = Promise<(Resource)>()
		
		if self.isLoaded {
			promise.success(self.resource!)
		} else {
			let query = Query(linkedResource: self)
			
			query.findResources().onSuccess { resourceCollection, meta in
				if let firstResource = resourceCollection.resources!.first {
					self.fulfill(firstResource)
				}
				promise.success(self.resource!)
			}.onFailure { error in
				promise.error(error)
			}
		}
		
		return promise.future
	}
	
	public func query() -> Query {
		return Query(linkedResource: self)
	}
	
	// MARK: ifLoaded
	
	public func ifLoaded(callback: (Resource) -> Void) -> Self {
		if self.isLoaded {
			callback(self.resource!)
		}
		
		return self
	}
	
	public func ifNotLoaded(callback: () -> Void) -> Self {
		if !self.isLoaded {
			callback()
		}
		
		return self
	}
}

public class ResourceCollection: NSObject, ArrayLiteralConvertible, Printable, Paginatable2 {
	/// Whether the resources for this collection are loaded
	public var isLoaded: Bool
	
	/// The link for this collection
	public var link: (href: NSURL, type: String, ids: [String]?)?
	
	/// The loaded resources
	public var resources: [Resource]?
	
	public var count: Int {
		return self.resources?.count ?? 0
	}
	
	/// Resources that are added to this collection
	var addedResources: [Resource] = []
	
	// MARK: Initializers
	
	public init(href: NSURL, type: String, ids: [String]? = nil) {
		self.link = (href, type, ids)
		self.isLoaded = false
	}
	
	public init(_ resources: [Resource]) {
		self.resources = resources
		self.isLoaded = true
	}
	
	public required init(arrayLiteral elements: Resource...) {
		self.resources = elements
		self.isLoaded = true
	}
	
	// MARK: Printable
	
	override public var description: String {
		if self.isLoaded {
			if let resources = self.resources {
				return "[" + ", ".join(resources.map { $0.description }) + "]"
			}
			return "(empty collection)"
		} else {
			return self.link!.href.absoluteString!
		}
	}

	// MARK: Mutators
	
	/**
	Adds a new resource to this collection.
	
	:param: newResource The resource to add.
	
	:returns: This collection.
	*/
	public func append(newResource: Resource) -> ResourceCollection {
		if self.resources == nil {
			self.resources = []
		}
		
		self.resources!.append(newResource)
		self.addedResources.append(newResource)
		return self
	}
	
	/**
	Sets the passed resources as the loaded resources and sets the isLoaded property to true.
	
	:param: resources The loaded resources.
	*/
	public func fulfill(resources: [Resource]) {
		self.resources = resources
		self.isLoaded = true
	}
	
	// MARK: Fetching
	
	/**
	Returns a query for this resource collection.
	
	:returns: The query
	*/
	public func query() -> Query {
		return Query(linkedResourceCollection: self)
	}
	
	/**
	Loads the resources if they are not yet loaded.
	
	:returns: A future promising an array of Resource objects.
	*/
	public func ensureResources() -> Future<([Resource])> {
		return self.ensureWithQuery(self.query())
	}
	
	/**
	Loads the resources if they are not yet loaded.
	The callback is passed a Query object that will be used to load the resources. In this callback, you can alter the query.
	For example, you could include related resources or change the sparse fieldset.
	
	:param: queryCallback The query callback.
	
	:returns: A future promising an array of Resource objects.
	*/
	public func ensureResourcesUsingQuery(queryCallback: (Query) -> Void) -> Future<([Resource])> {
		let query = self.query()
		queryCallback(query)
		return self.ensureWithQuery(query)
	}
	
	/**
	Loads the resources using a given query if they are not yet loaded.
	
	:param: query The query to load the resources.
	
	:returns: A future promising an array of Resource objects.
	*/
	private func ensureWithQuery(query: Query)  -> Future<([Resource])> {
		let promise = Promise<([Resource])>()
		
		if self.isLoaded {
			promise.success(self.resources!)
		} else {
			query.findResources().onSuccess { resourceCollection, meta in
				self.fulfill(resourceCollection.resources!)
				promise.success(self.resources!)
			}.onFailure { error in
				promise.error(error)
			}
		}
		
		return promise.future
	}
	
	// MARK: ifLoaded
	
	/**
	Calls the passed callback if the resources are loaded.
	
	:param: callback A function taking an array of Resource objects.
	
	:returns: This collection.
	*/
	public func ifLoaded(callback: ([Resource]) -> Void) -> Self {
		if self.isLoaded {
			callback(self.resources!)
		}
		
		return self
	}
	
	/**
	Calls the passed callback if the resources are not loaded.
	
	:param: callback A function
	
	:returns: This collection
	*/
	public func ifNotLoaded(callback: () -> Void) -> Self {
		if !self.isLoaded {
			callback()
		}
		
		return self
	}
	
	// MARK: Paginatable
	
	public var beforeCursor: String?
	public var afterCursor: String?
	public var pageSize: Int?
	
	public var canFetchNextPage: Bool {
		return self.afterCursor != nil
	}
	
	public var canFetchPreviousPage: Bool {
		return self.beforeCursor != nil
	}
	
	public func fetchNextPage() {
		assert(self.canFetchNextPage, "Cannot fetch the next page.")
	}
	
	public func fetchPreviousPage() {
		assert(self.canFetchPreviousPage, "Cannot fetch the previous page.")
	}
	
	private func nextPageURL() -> NSURL? {
		if let cursor = self.beforeCursor {
			let queryParts = "limit=\(self.pageSize)&before=\(cursor)"
		}
		
		return nil
	}
	
	private func previousPageURL() -> NSURL? {
		if let cursor = self.afterCursor {
			let queryParts = "limit=\(self.pageSize)&after=\(cursor)"
		}
		
		return nil
	}
	
}


// MARK: - Convenience functions

extension Resource {
	
	/**
	Saves this resource asynchronously.
	
	:returns: A future of this resource.
	*/
	public func save() -> Future<Resource> {
		return Spine.sharedInstance.saveResource(self)
	}

	/**
	Deletes this resource asynchronously.
	
	:returns: A void future.
	*/
	public func delete() -> Future<Void> {
		return Spine.sharedInstance.deleteResource(self)
	}

	/**
	Finds one resource of this type with a given ID.
	
	:param: ID The ID of the resource to find.
	
	:returns: A future of Resource.
	*/
	public class func findOne(ID: String) -> Future<(Resource, Meta?)> {
		let instance = self()
		return Spine.sharedInstance.fetchResourceWithType(instance.type, ID: ID)
	}

	/**
	Finds multiple resources of this type by given IDs.
	
	:param: IDs The IDs of the resources to find.
	
	:returns: A future of an array of resources.
	*/
	public class func find(IDs: [String]) -> Future<(ResourceCollection, Meta?)> {
		let instance = self()
		let query = Query(resourceType: instance.type, resourceIDs: IDs)
		return Spine.sharedInstance.fetchResourcesForQuery(query)
	}

	/**
	Finds all resources of this type.
	
	:returns: A future of an array of resources.
	*/
	public class func findAll() -> Future<(ResourceCollection, Meta?)> {
		let instance = self()
		let query = Query(resourceType: instance.type)
		return Spine.sharedInstance.fetchResourcesForQuery(query)
	}
	

	// TODO: Fix
	
	/**
	Finds resources related to this resource by the given relationship.
	
	:param: relationship Name of the relationship.
	
	:returns: A future of an array of resources.
	*/
//	public func findRelated(relationship: String) -> Future<([Resource], Meta?)> {
//		let query = Query(resource: self, relationship: relationship)
//		return Spine.sharedInstance.fetchResourcesForQuery(query)
//	}
}


//MARK: - Meta

public class Meta: Resource {
	final override public var type: String {
		return "_meta"
	}
}