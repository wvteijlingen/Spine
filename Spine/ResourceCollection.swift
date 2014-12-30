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