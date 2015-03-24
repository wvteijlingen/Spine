//
//  ResourceCollection.swift
//  Spine
//
//  Created by Ward van Teijlingen on 30-12-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation
import BrightFutures

/**
 *  A ResourceCollection represents a collection of resources.
 *  It contains a URL where the resources can be fetched.
 *  For collections that can be paginated, pagination data is stored as well.
 */
public class ResourceCollection: NSObject, NSCoding, Paginatable {
	/// Whether the resources for this collection are loaded
	public var isLoaded: Bool
	
	/// The URL where the resources in this collection can be fetched
	public var resourcesURL: NSURL?
	
	/// The loaded resources
	public internal(set) var resources: [ResourceProtocol] = []
	
	var paginationData: PaginationData?
	
	// MARK: Initializers
	
	public init(resourcesURL: NSURL? = nil, resources: [ResourceProtocol]) {
		self.resourcesURL = resourcesURL
		self.resources = resources
		self.isLoaded = !isEmpty(resources)
	}
	
	// MARK: NSCoding
	
	public required init(coder: NSCoder) {
		isLoaded = coder.decodeBoolForKey("isLoaded")
		resourcesURL = coder.decodeObjectForKey("resourcesURL") as? NSURL
		resources = coder.decodeObjectForKey("resources") as [ResourceProtocol]
		
		if let paginationData = coder.decodeObjectForKey("paginationData") as? NSDictionary {
			self.paginationData = PaginationData.fromDictionary(paginationData)
		}
	}
	
	public func encodeWithCoder(coder: NSCoder) {
		coder.encodeBool(isLoaded, forKey: "isLoaded")
		coder.encodeObject(resourcesURL, forKey: "resourcesURL")
		coder.encodeObject(resources, forKey: "resources")
		coder.encodeObject(paginationData?.toDictionary(), forKey: "paginationData")
	}
	
	// MARK: Subscript and count
	
	/// Returns the loaded resource at the given index.
	public subscript (index: Int) -> ResourceProtocol {
		return resources[index]
	}
	
	/// Returns a loaded resource identified by the given type and id,
	/// or nil if no loaded resource was found.
	public subscript (type: String, id: String) -> ResourceProtocol? {
		return resources.filter { $0.id == id && $0.type == type }.first
	}
	
	/// Returns how many resources are loaded.
	public var count: Int {
		return resources.count
	}
}

extension ResourceCollection {
	/**
	Calls the passed callback if the resources are loaded.
	
	:param: callback A function taking an array of Resource objects.
	
	:returns: This collection.
	*/
	public func ifLoaded(callback: ([ResourceProtocol]) -> Void) -> Self {
		if isLoaded {
			callback(resources)
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
}

extension ResourceCollection: Paginatable {
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

extension ResourceCollection: SequenceType {
	public typealias Generator = IndexingGenerator<[ResourceProtocol]>
	
	public func generate() -> Generator {
		return resources.generate()
	}
}

/**
 *  A LinkedResourceCollection represents a collection of resources that is linked from another resource.
 *  The main differences with ResourceCollection is that it is mutable, and the addition of `linkage`,
 *  and a self `URL` property.
 *
 *  A LinkedResourceCollection keeps track of resources that are added to and removed from the collection.
 *  This allows Spine to make partial updates to the collection when it is persisted.
 */
public class LinkedResourceCollection: ResourceCollection {
	/// The self URL of this link.
	public var URL: NSURL?
	
	/// The type/id pairs of resources present in this link.
	public var linkage: [(type: ResourceType, id: String)]?
	
	/// Resources added to this linked collection, but not yet persisted.
	public internal(set) var addedResources: [ResourceProtocol] = []
	
	/// Resources removed from this linked collection, but not yet persisted.
	public internal(set) var removedResources: [ResourceProtocol] = []
	
	public required init() {
		super.init(resourcesURL: nil, resources: [])
	}
	
	public init(resourcesURL: NSURL? = nil, URL: NSURL? = nil, linkage: [(type: ResourceType, id: String)]? = nil) {
		super.init(resourcesURL: resourcesURL, resources: [])
		self.URL = URL
		self.linkage = linkage
	}
	
	public convenience init(resourcesURL: NSURL? = nil, URL: NSURL? = nil, homogenousType: ResourceType, linkage: [String]? = nil) {
		self.init(resourcesURL: resourcesURL, URL: URL, linkage: linkage?.map { (type: homogenousType, id: $0) })
	}
	
	public required init(coder: NSCoder) {
		super.init(coder: coder)
		URL = coder.decodeObjectForKey("URL") as? NSURL
		addedResources = coder.decodeObjectForKey("addedResources") as [ResourceProtocol]
		removedResources = coder.decodeObjectForKey("removedResources") as [ResourceProtocol]
		
		if let encodedLinkage = coder.decodeObjectForKey("linkage") as? [[String: String]] {
			linkage = []
			for linkageItem in encodedLinkage {
				linkage!.append(type: linkageItem["type"]!, id: linkageItem["id"]!)
			}
		}
	}
	
	public override func encodeWithCoder(coder: NSCoder) {
		super.encodeWithCoder(coder)
		coder.encodeObject(URL, forKey: "URL")
		coder.encodeObject(addedResources, forKey: "addedResources")
		coder.encodeObject(removedResources, forKey: "removedResources")
		
		if let linkage = linkage {
			var encodedLinkage: [[String: String]] = [[:]]
			for linkageItem in linkage {
				encodedLinkage.append(["type": linkageItem.type, "id": linkageItem.id])
			}
			
			coder.encodeObject(encodedLinkage, forKey: "linkage")
		}
	}
	
	// MARK: Mutators
	
	/// Adds the given resource to this collection.
	public func add(resource: ResourceProtocol) {
		resources.append(resource)
		addedResources.append(resource)
		removedResources = removedResources.filter { $0 !== resource }
	}
	
	/// Removes the given resource from this collection.
	public func remove(resource: ResourceProtocol) {
		resources = resources.filter { $0 !== resource }
		addedResources = addedResources.filter { $0 !== resource }
		removedResources.append(resource)
	}
	
	/// Adds the given resource to this collection, but does not mark it as added.
	internal func addAsExisting(resource: ResourceProtocol) {
		resources.append(resource)
		removedResources = removedResources.filter { $0 !== resource }
		addedResources = addedResources.filter { $0 !== resource }
	}
}

extension LinkedResourceCollection: ExtensibleCollectionType {
	public var startIndex: Int { return resources.startIndex }
	public var endIndex: Int { return resources.endIndex }

	public func reserveCapacity(n: Int) {
		resources.reserveCapacity(n)
	}
	
	public func append(newElement: ResourceProtocol) {
		self.add(newElement)
	}
	
	public func extend<S : SequenceType where S.Generator.Element == ResourceProtocol>(seq: S) {
		for element in seq {
			self.add(element)
		}
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
	var firstURL: NSURL?
	var lastURL: NSURL?
	var nextURL: NSURL?
	var previousURL: NSURL?
	
	func toDictionary() -> NSDictionary {
		var dictionary = NSDictionary()
		
		if let count = count {
			dictionary.setValue(NSNumber(integer: count), forKey: "count")
		}
		
		if let limit = limit {
			dictionary.setValue(NSNumber(integer: limit), forKey: "limit")
		}
		
		if let beforeCursor = beforeCursor {
			dictionary.setValue(beforeCursor, forKey: "beforeCursor")
		}
		if let afterCursor = afterCursor {
			dictionary.setValue(afterCursor, forKey: "afterCursor")
		}
		
		if let firstURL = firstURL {
			dictionary.setValue(firstURL, forKey: "firstURL")
		}
		if let lastURL = lastURL {
			dictionary.setValue(lastURL, forKey: "lastURL")
		}
		
		if let nextURL = nextURL {
			dictionary.setValue(nextURL, forKey: "nextURL")
		}
		if let previousURL = previousURL {
			dictionary.setValue(nextURL, forKey: "previousURL")
		}
		
		return dictionary
	}
	
	static func fromDictionary(dictionary: NSDictionary) -> PaginationData {
		return PaginationData(
			count: (dictionary.valueForKey("count") as? NSNumber)?.integerValue,
			limit: (dictionary.valueForKey("limit") as? NSNumber)?.integerValue,
			beforeCursor: dictionary.valueForKey("beforeCursor") as? String,
			afterCursor: dictionary.valueForKey("afterCursor") as? String,
			
			firstURL: dictionary.valueForKey("firstURL") as? NSURL,
			lastURL: dictionary.valueForKey("lastURL") as? NSURL,
			
			nextURL: dictionary.valueForKey("nextURL") as? NSURL,
			previousURL: dictionary.valueForKey("previousURL") as? NSURL
		)
	}
}