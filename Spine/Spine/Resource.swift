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
	
	/// The resource's unique identifier. If this is nil, the resource cannot be uniquely identified.
	var uniqueIdentifier: ResourceIdentifier? { get }
	
	/// The location (URL) of this resource.
	var href: String? { get set }
}

protocol Mappable {
	/// Array of attributes that must be mapped by Spine.
	var persistentAttributes: [String: ResourceAttribute] { get }
}

protocol Paginatable {
	var paginationData: PaginationData? { get set }
	var canFetchNextPage: Bool { get }
	var canFetchPreviousPage: Bool { get }
	func fetchNextPage() -> Future<Void>
	func fetchPreviousPage() -> Future<Void>
}

struct PaginationData {
	var count: Int?
	var limit: Int?
	var beforeCursor: String?
	var afterCursor: String?
	var nextHref: NSURL?
	var previousHref: NSURL?
	
	func toDictionary() -> NSDictionary {
		var dictionary = NSDictionary()
		
		if let count = self.count {
			dictionary.setValue(NSNumber(integer: count), forKey: "count")
		}
		
		if let limit = self.limit {
			dictionary.setValue(NSNumber(integer: limit), forKey: "limit")
		}
		
		if let beforeCursor = self.beforeCursor {
			dictionary.setValue(beforeCursor, forKey: "beforeCursor")
		}
		
		if let afterCursor = self.afterCursor {
			dictionary.setValue(afterCursor, forKey: "afterCursor")
		}
		
		if let nextHref = self.nextHref {
			dictionary.setValue(nextHref, forKey: "nextHref")
		}
		
		if let previousHref = self.previousHref {
			dictionary.setValue(previousHref, forKey: "previousHref")
		}
		
		return dictionary
	}
	
	static func fromDictionary(dictionary: NSDictionary) -> PaginationData {
		return PaginationData(
			count: (dictionary.valueForKey("count") as? NSNumber)?.integerValue,
			limit: (dictionary.valueForKey("limit") as? NSNumber)?.integerValue,
			beforeCursor: dictionary.valueForKey("beforeCursor") as? String,
			afterCursor: dictionary.valueForKey("afterCursor") as? String,
			nextHref: dictionary.valueForKey("nextHref") as? NSURL,
			previousHref: dictionary.valueForKey("previousHref") as? NSURL
		)
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


// MARK: -

/**
*  A base recource class that provides some defaults for resources.
*  You must create custom resource classes by subclassing from Resource.
*/
public class Resource: NSObject, Identifiable, Mappable, NSCoding, Printable {
	
	// MARK: Initializers
	
	// This is needed for the dynamic instantiation based on the metatype
	required override public init() {
		super.init()
	}
	
	public init(id: String) {
		super.init()
		self.id = id
	}
	
	// MARK: NSCoding protocol
	
	public required init(coder: NSCoder) {
		super.init()
		self.id = coder.decodeObjectForKey("id") as? String
		self.href = coder.decodeObjectForKey("href") as? String
	}
	
	public func encodeWithCoder(coder: NSCoder) {
		coder.encodeObject(self.id, forKey: "id")
		coder.encodeObject(self.href, forKey: "href")
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

public class LinkedResource: NSObject, NSCoding, Printable {
	public var isLoaded: Bool
	public var link: (href: NSURL?, type: String, id: String?)?
	public var resource: Resource?
	
	// MARK: Initializers
	
	public init(href: NSURL?, type: String, id: String? = nil) {
		self.link = (href, type, id)
		self.isLoaded = false
	}
	
	public init(_ resource: Resource) {
		self.resource = resource
		self.isLoaded = true
	}
	
	// MARK: NSCoding
	
	public required init(coder: NSCoder) {
		self.isLoaded = coder.decodeBoolForKey("isLoaded")
		self.resource = coder.decodeObjectForKey("resource") as? Resource

		if let type = coder.decodeObjectForKey("linkType") as? String {
			self.link = (href: coder.decodeObjectForKey("linkHref") as? NSURL, type: type, id: coder.decodeObjectForKey("linkID") as? String)
		}
	}
	
	public func encodeWithCoder(coder: NSCoder) {
		coder.encodeBool(self.isLoaded, forKey: "isLoaded")
		coder.encodeObject(self.resource, forKey: "resource")
		
		if let link = self.link {
			coder.encodeObject(link.href, forKey: "linkHref")
			coder.encodeObject(link.type, forKey: "linkType")
			coder.encodeObject(link.id, forKey: "linkID")
		}
	}
	
	// MARK: Printable
	
	override public var description: String {
		if self.isLoaded {
			if let resource = self.resource {
				return "LinkedResource.loaded<\(self.link!.type)>(\(resource.description))"
			} else {
				return "LinkedResource.loaded<\(self.link!.type)>()"
			}
		} else if let URLString = self.link!.href?.absoluteString {
			return "LinkedResource.link<\(self.link!.type)>(\(URLString))"
		} else {
			return "LinkedResource.link<\(self.link!.type)>(\(self.link!.id))"
		}
	}
	
	// MARK: Mutators
	
	public func fulfill(resource: Resource) {
		self.resource = resource
		self.isLoaded = true
	}
	
	// MARK: Fetching
	
	public func query() -> Query {
		return Query(linkedResource: self)
	}
	
	public func ensureResource() -> Future<(Resource)> {
		return self.ensureWithQuery(self.query())
	}
	
	public func ensureResource(queryCallback: (Query) -> Void) -> Future<(Resource)> {
		let query = self.query()
		queryCallback(query)
		return self.ensureWithQuery(query)
	}
	
	private func ensureWithQuery(query: Query)  -> Future<(Resource)> {
		let promise = Promise<(Resource)>()
		
		if self.isLoaded {
			promise.success(self.resource!)
		} else {
			query.findOne().onSuccess { resource in
				self.fulfill(resource)
				promise.success(self.resource!)
			}.onFailure { error in
				promise.error(error)
			}
		}
		
		return promise.future
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


//MARK: -

public class ResourceCollection: NSObject, NSCoding, ArrayLiteralConvertible, SequenceType, Printable, Paginatable {
	/// Whether the resources for this collection are loaded
	public var isLoaded: Bool
	
	/// The link for this collection
	public var link: (href: NSURL?, type: String, ids: [String]?)?
	
	/// The count of the loaded resources
	public var count: Int {
		return self.resources?.count ?? 0
	}
	
	/// The loaded resources
	public var resources: [Resource]? {
		didSet {
			if !observeResources {
				return
			}
			
			let previousItems: [Resource] = oldValue ?? []
			let newItems: [Resource] = self.resources ?? []
			
			let addedItems = newItems.filter { item in
				return !contains(previousItems, item)
			}
			
			let removedItems = previousItems.filter { item in
				return !contains(newItems, item)
			}
			
			self.addedResources += addedItems
			self.removedResources += removedResources
		}
	}
	
	var observeResources: Bool = true
	
	/// Resources that are added to this collection
	var addedResources: [Resource] = []
	
	/// Resources that are removed from this collection
	var removedResources: [Resource] = []
	
	var paginationData: PaginationData?
	
	// MARK: Initializers
	
	public init(href: NSURL?, type: String, ids: [String]? = nil) {
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
	
	// MARK: NSCoding
	
	public required init(coder: NSCoder) {
		self.isLoaded = coder.decodeBoolForKey("isLoaded")
		self.resources = coder.decodeObjectForKey("resources") as? [Resource]
		
		if let paginationData = coder.decodeObjectForKey("paginationData") as? NSDictionary {
			self.paginationData = PaginationData.fromDictionary(paginationData)
		}

		if let type = coder.decodeObjectForKey("linkType") as? String {
			self.link = (href: coder.decodeObjectForKey("linkHref") as? NSURL, type: type, ids: coder.decodeObjectForKey("linkID") as? [String])
		}
	}
	
	public func encodeWithCoder(coder: NSCoder) {
		coder.encodeBool(self.isLoaded, forKey: "isLoaded")
		coder.encodeObject(self.resources, forKey: "resources")
		coder.encodeObject(self.resources, forKey: "resources")
		coder.encodeObject(self.paginationData?.toDictionary(), forKey: "paginationData")
		
		if let link = self.link {
			coder.encodeObject(link.href, forKey: "linkHref")
			coder.encodeObject(link.type, forKey: "linkType")
			coder.encodeObject(link.ids, forKey: "linkID")
		}
	}
	
	// MARK: Printable protocol
	
	override public var description: String {
		if self.isLoaded {
			if let resources = self.resources {
				let descriptions = ", ".join(resources.map { $0.description })
				return "ResourceCollection.loaded<\(self.link!.type)>(\(descriptions))"
			} else {
				return "ResourceCollection.loaded<\(self.link!.type)>([])"
			}
		} else if let URLString = self.link!.href?.absoluteString {
			return "ResourceCollection.link<\(self.link!.type)>(\(URLString))"
		} else {
			let IDs = ", ".join(self.link!.ids!)
			return "ResourceCollection.link<\(self.link!.type)>(\(IDs))"
		}
	}
	
	// MARK: SequenceType protocol
	
	public func generate() -> GeneratorOf<Resource> {
		let allObjects: [Resource] = self.resources ?? []
		var index = -1
		
		return GeneratorOf<Resource> {
			index++
			
			if (index > allObjects.count - 1) {
				return nil
			}
			
			return allObjects[index]
		}
	}
	
	// Subscript and count
	
	public subscript (index: Int) -> Resource? {
		return self.resources?[index]
	}
	
	public subscript (id: String) -> Resource? {
		let foundResources = self.resources?.filter { resource in
			return resource.id == id
		}
		
		return foundResources?.first
	}

	// MARK: Mutators
	
	/**
	Sets the passed resources as the loaded resources and sets the isLoaded property to true.
	The resources array will not be observed during fulfilling.
	
	:param: resources The loaded resources.
	*/
	public func fulfill(resources: [Resource]) {
		self.observeResources = false
		
		self.resources = resources
		self.isLoaded = true
		
		self.observeResources = true
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
	public func ensureResources(queryCallback: (Query) -> Void) -> Future<([Resource])> {
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
			query.find().onSuccess { resourceCollection in
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
	
	public var canFetchNextPage: Bool {
		return self.paginationData?.afterCursor != nil
	}
	
	public var canFetchPreviousPage: Bool {
		return self.paginationData?.beforeCursor != nil
	}
	
	public func fetchNextPage() -> Future<Void> {
		assert(self.canFetchNextPage, "Cannot fetch the next page.")
		let promise = Promise<(Void)>()
		return promise.future
	}
	
	public func fetchPreviousPage() -> Future<Void> {
		assert(self.canFetchPreviousPage, "Cannot fetch the previous page.")
		let promise = Promise<(Void)>()
		return promise.future
	}
	
	private func nextPageURL() -> NSURL? {
		if let cursor = self.paginationData?.afterCursor {
			let queryParts = "limit=\(self.paginationData?.limit)&after=\(cursor)"
		}
		
		return nil
	}
	
	private func previousPageURL() -> NSURL? {
		if let cursor = self.paginationData?.beforeCursor {
			let queryParts = "limit=\(self.paginationData?.limit)&before=\(cursor)"
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
	public class func findOne(ID: String) -> Future<Resource> {
		let instance = self()
		let query = Query(resourceType: instance.type, resourceIDs: [ID])
		return Spine.sharedInstance.fetchResourceForQuery(query)
	}

	/**
	Finds multiple resources of this type by given IDs.
	
	:param: IDs The IDs of the resources to find.
	
	:returns: A future of an array of resources.
	*/
	public class func find(IDs: [String]) -> Future<ResourceCollection> {
		let instance = self()
		let query = Query(resourceType: instance.type, resourceIDs: IDs)
		return Spine.sharedInstance.fetchResourcesForQuery(query)
	}

	/**
	Finds all resources of this type.
	
	:returns: A future of an array of resources.
	*/
	public class func findAll() -> Future<ResourceCollection> {
		let instance = self()
		let query = Query(resourceType: instance.type)
		return Spine.sharedInstance.fetchResourcesForQuery(query)
	}
}


//MARK: - Meta

public class Meta: Resource {
	final override public var type: String {
		return "_meta"
	}
}