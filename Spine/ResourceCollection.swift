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
	
	/// The loaded resources
	private var _resources: [ResourceProtocol] = []
	public var resources: [ResourceProtocol] { return _resources }

	var observeResources: Bool = true
	
	/// Resources that are added to this collection
	var addedResources: [ResourceProtocol] = []
	
	/// Resources that are removed from this collection
	var removedResources: [ResourceProtocol] = []
	
	var paginationData: PaginationData?
	
	// MARK: Initializers
	
	public init(href: NSURL? = nil, type: String, ids: [String]? = nil) {
		self.href = href
		self.type = type
		self.ids = ids
		self.isLoaded = false
	}
	
	public init(_ resources: [ResourceProtocol]) {
		self.type = resources.first!.type
		self._resources = resources
		self.isLoaded = true
	}
	
	public required init(arrayLiteral elements: ResourceProtocol...) {
		self.type = elements.first!.type
		self._resources = elements
		self.isLoaded = true
	}
	
	// MARK: NSCoding
	
	public required init(coder: NSCoder) {
		isLoaded = coder.decodeBoolForKey("isLoaded")
		type = coder.decodeObjectForKey("type") as String
		href = coder.decodeObjectForKey("href") as? NSURL
		ids = coder.decodeObjectForKey("ids") as? [String]
		_resources = coder.decodeObjectForKey("resources") as [ResourceProtocol]
		addedResources = coder.decodeObjectForKey("addedResources") as [ResourceProtocol]
		removedResources = coder.decodeObjectForKey("removedResources") as [ResourceProtocol]
		
		if let paginationData = coder.decodeObjectForKey("paginationData") as? NSDictionary {
			self.paginationData = PaginationData.fromDictionary(paginationData)
		}
	}
	
	public func encodeWithCoder(coder: NSCoder) {
		coder.encodeBool(isLoaded, forKey: "isLoaded")
		coder.encodeObject(href, forKey: "href")
		coder.encodeObject(type, forKey: "type")
		coder.encodeObject(ids, forKey: "ids")
		coder.encodeObject(resources, forKey: "resources")
		coder.encodeObject(addedResources, forKey: "addedResources")
		coder.encodeObject(removedResources, forKey: "removedResources")
		coder.encodeObject(paginationData?.toDictionary(), forKey: "paginationData")
	}
	
	// MARK: Printable protocol
	
	override public var description: String {
		if self.isLoaded {
			let descriptions = ", ".join(resources.map { "\($0.type):\($0.type)" })
			return "ResourceCollection.loaded<\(self.type)>[\(descriptions)]"
		} else if let URLString = self.href?.absoluteString {
			return "ResourceCollection.link<\(self.type)>(\(URLString))"
		} else {
			let IDs = ", ".join(self.ids!)
			return "ResourceCollection.link<\(self.type)>(\(IDs))"
		}
	}
	
	// MARK: SequenceType protocol
	
	public func generate() -> GeneratorOf<ResourceProtocol> {
		let allObjects: [ResourceProtocol] = resources
		var index = -1
		
		return GeneratorOf<ResourceProtocol> {
			index++
			
			if (index > allObjects.count - 1) {
				return nil
			}
			
			return allObjects[index]
		}
	}
	
	// Subscript and count
	
	public subscript (index: Int) -> ResourceProtocol? {
		return resources[index]
	}
	
	public subscript (id: String) -> ResourceProtocol? {
		let foundResources = self.resources.filter { resource in
			return resource.id == id
		}
		
		return foundResources.first
	}
	
	public var count: Int {
		return resources.count
	}
	
	// MARK: Mutators

	public func add(resource: ResourceProtocol) {
		_resources.append(resource)
		addedResources.append(resource)
		removedResources = removedResources.filter { $0 !== resource }
	}
	
	public func remove(resource: ResourceProtocol) {
		_resources = resources.filter { $0 !== resource }
		addedResources = addedResources.filter { $0 !== resource }
		removedResources.append(resource)
	}
	
	internal func addAsExisting(resource: ResourceProtocol) {
		_resources.append(resource)
		removedResources = removedResources.filter { $0 !== resource }
		addedResources = addedResources.filter { $0 !== resource }
	}
	
	internal func fulfill(resources: [ResourceProtocol]) {
		_resources = resources
		isLoaded = true
	}
	
	// MARK: Fetching
	
	/**
	Returns a query for this resource collection.
	
	:returns: The query
	*/
	public func query() -> Query<ResourceProtocol> {
		return Query(linkedResourceCollection: self)
	}
	
	// MARK: ifLoaded
	
	/**
	Calls the passed callback if the resources are loaded.
	
	:param: callback A function taking an array of Resource objects.
	
	:returns: This collection.
	*/
	public func ifLoaded(callback: ([ResourceProtocol]) -> Void) -> Self {
		if isLoaded {
			callback(self.resources)
		}
		
		return self
	}
	
	/**
	Calls the passed callback if the resources are not loaded.
	
	:param: callback A function
	
	:returns: This collection
	*/
	public func ifNotLoaded(callback: () -> Void) -> Self {
		if !isLoaded {
			callback()
		}
		
		return self
	}
	
	// MARK: Paginatable
	
	public var canFetchNextPage: Bool {
		return paginationData?.afterCursor != nil
	}
	
	public var canFetchPreviousPage: Bool {
		return paginationData?.beforeCursor != nil
	}
	
	public func fetchNextPage() -> Future<Void> {
		assert(canFetchNextPage, "Cannot fetch the next page.")
		let promise = Promise<(Void)>()
		return promise.future
	}
	
	public func fetchPreviousPage() -> Future<Void> {
		assert(canFetchPreviousPage, "Cannot fetch the previous page.")
		let promise = Promise<(Void)>()
		return promise.future
	}
	
	private func nextPageURL() -> NSURL? {
		if let cursor = paginationData?.afterCursor {
			let queryParts = "limit=\(self.paginationData?.limit)&after=\(cursor)"
		}
		
		return nil
	}
	
	private func previousPageURL() -> NSURL? {
		if let cursor = paginationData?.beforeCursor {
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