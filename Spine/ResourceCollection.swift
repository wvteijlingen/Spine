//
//  ResourceCollection.swift
//  Spine
//
//  Created by Ward van Teijlingen on 30-12-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation
import BrightFutures

public class ResourceCollection: NSObject, NSCoding, ArrayLiteralConvertible, SequenceType, Printable, Paginatable {
	/// Whether the resources for this collection are loaded
	public var isLoaded: Bool
	public var type: String
	public var ids: [String]?
	public var href: NSURL?
	
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
		self.href = href
		self.type = type
		self.ids = ids
		self.isLoaded = false
	}
	
	public init(_ resources: [Resource]) {
		self.type = resources.first!.dynamicType.type
		self.resources = resources
		self.isLoaded = true
	}
	
	public required init(arrayLiteral elements: Resource...) {
		self.type = elements.first!.dynamicType.type
		self.resources = elements
		self.isLoaded = true
	}
	
	// MARK: NSCoding
	
	public required init(coder: NSCoder) {
		isLoaded = coder.decodeBoolForKey("isLoaded")
		resources = coder.decodeObjectForKey("resources") as? [Resource]
		
		if let paginationData = coder.decodeObjectForKey("paginationData") as? NSDictionary {
			self.paginationData = PaginationData.fromDictionary(paginationData)
		}
		
		type = coder.decodeObjectForKey("type") as String
		href = coder.decodeObjectForKey("href") as? NSURL
		ids = coder.decodeObjectForKey("ids") as? [String]
	}
	
	public func encodeWithCoder(coder: NSCoder) {
		coder.encodeBool(isLoaded, forKey: "isLoaded")
		coder.encodeObject(resources, forKey: "resources")
		coder.encodeObject(resources, forKey: "resources")
		coder.encodeObject(paginationData?.toDictionary(), forKey: "paginationData")
		
		coder.encodeObject(href, forKey: "href")
		coder.encodeObject(type, forKey: "type")
		coder.encodeObject(ids, forKey: "ids")
	}
	
	// MARK: Printable protocol
	
	override public var description: String {
		if self.isLoaded {
			if let resources = self.resources {
				let descriptions = ", ".join(resources.map { $0.description })
				return "ResourceCollection.loaded<\(self.type)>(\(descriptions))"
			} else {
				return "ResourceCollection.loaded<\(self.type)>([])"
			}
		} else if let URLString = self.href?.absoluteString {
			return "ResourceCollection.link<\(self.type)>(\(URLString))"
		} else {
			let IDs = ", ".join(self.ids!)
			return "ResourceCollection.link<\(self.type)>(\(IDs))"
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
	public func query() -> Query<Resource> {
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
	public func ensureResources(queryCallback: (Query<Resource>) -> Void) -> Future<([Resource])> {
		let query = self.query()
		queryCallback(query)
		return self.ensureWithQuery(query)
	}
	
	/**
	Loads the resources using a given query if they are not yet loaded.
	
	:param: query The query to load the resources.
	
	:returns: A future promising an array of Resource objects.
	*/
	private func ensureWithQuery(query: Query<Resource>) -> Future<([Resource])> {
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


// MARK: - Collection pagination

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