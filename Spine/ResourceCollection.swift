//
//  ResourceCollection.swift
//  Spine
//
//  Created by Ward van Teijlingen on 30-12-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation
import BrightFutures

public class ResourceCollection: NSObject, NSCoding, Paginatable, Linkable {
	public enum Composition {
		case Unknown
		case Homogenous(type: String)
		case Heterogenous
		
		func toDictionary() -> NSDictionary {
			switch self {
			case .Unknown:
				return ["Composition": "Unknown"]
			case .Homogenous(let type):
				return ["Composition": "Homogenous", "Type": type]
			case .Heterogenous:
				return ["Heterogenous": "Heterogenous"]
			}
		}
		static func fromDictionary(dictionary: NSDictionary) -> Composition {
			switch dictionary["Composition"] as String {
			case "Homogenous":
				return .Homogenous(type: dictionary["Type"] as String)
			case "Heterogenous":
				return .Heterogenous
			default:
				return .Unknown
			}
		}
	}
	
	/// Whether the resources for this collection are loaded
	public var isLoaded: Bool
	
	public var composition: Composition = .Unknown
	public var URL: NSURL?
	public var resourcesURL: NSURL?
	public var linkage: [(type: String, id: String)]?
	
	/// The loaded resources
	public private(set) var resources: [ResourceProtocol] = []
	
	/// Resources that are added to this collection
	var addedResources: [ResourceProtocol] = []
	
	/// Resources that are removed from this collection
	var removedResources: [ResourceProtocol] = []
	
	var paginationData: PaginationData?
	
	
	// MARK: Initializers
	
	public init(resourcesURL: NSURL? = nil, URL: NSURL? = nil, composition: Composition, linkage: [(type: String, id: String)]? = nil) {
		self.resourcesURL = resourcesURL
		self.URL = URL
		self.composition = composition
		self.linkage = linkage
		self.isLoaded = false
	}
	
	public init(resourcesURL: NSURL? = nil, URL: NSURL? = nil, homogenousType: String, linkage: [String]? = nil) {
		self.resourcesURL = resourcesURL
		self.URL = URL
		self.composition = .Homogenous(type: homogenousType )
		self.linkage = linkage?.map { (type: homogenousType, id: $0) }
		self.isLoaded = false
	}
	
	public init(_ resources: [ResourceProtocol]) {
		self.composition = .Unknown
		self.resources = resources
		self.isLoaded = true
	}
	
	// MARK: NSCoding
	
	public required init(coder: NSCoder) {
		isLoaded = coder.decodeBoolForKey("isLoaded")
		composition = Composition.fromDictionary(coder.decodeObjectForKey("composition") as NSDictionary)
		URL = coder.decodeObjectForKey("URL") as? NSURL
		resourcesURL = coder.decodeObjectForKey("resourcesURL") as? NSURL
		resources = coder.decodeObjectForKey("resources") as [ResourceProtocol]
		addedResources = coder.decodeObjectForKey("addedResources") as [ResourceProtocol]
		removedResources = coder.decodeObjectForKey("removedResources") as [ResourceProtocol]
		
		if let paginationData = coder.decodeObjectForKey("paginationData") as? NSDictionary {
			self.paginationData = PaginationData.fromDictionary(paginationData)
		}
		
		if let encodedLinkage = coder.decodeObjectForKey("linkage") as? [[String: String]] {
			linkage = []
			for linkageItem in encodedLinkage {
				linkage!.append(type: linkageItem["type"]!, id: linkageItem["id"]!)
			}
		}
	}
	
	public func encodeWithCoder(coder: NSCoder) {
		coder.encodeBool(isLoaded, forKey: "isLoaded")
		coder.encodeObject(URL, forKey: "URL")
		coder.encodeObject(resourcesURL, forKey: "resourcesURL")
		coder.encodeObject(composition.toDictionary(), forKey: "composition")
		coder.encodeObject(resources, forKey: "resources")
		coder.encodeObject(addedResources, forKey: "addedResources")
		coder.encodeObject(removedResources, forKey: "removedResources")
		coder.encodeObject(paginationData?.toDictionary(), forKey: "paginationData")
		
		if let linkage = linkage {
			var encodedLinkage: [[String: String]] = [[:]]
			for linkageItem in linkage {
				encodedLinkage.append(["type": linkageItem.type, "id": linkageItem.id])
			}
			
			coder.encodeObject(encodedLinkage, forKey: "linkage")
		}
	}
	
	// Subscript and count
	
	public subscript (index: Int) -> ResourceProtocol {
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

	public func append(resource: ResourceProtocol) {
		validateResourceAddition(resource)
		
		resources.append(resource)
		addedResources.append(resource)
		removedResources = removedResources.filter { $0 !== resource }
	}
	
	public func remove(resource: ResourceProtocol) {
		resources = resources.filter { $0 !== resource }
		addedResources = addedResources.filter { $0 !== resource }
		removedResources.append(resource)
	}
	
	internal func addAsExisting(resource: ResourceProtocol) {
		validateResourceAddition(resource)
		
		resources.append(resource)
		removedResources = removedResources.filter { $0 !== resource }
		addedResources = addedResources.filter { $0 !== resource }
	}
	
	internal func fulfill(resources: [ResourceProtocol]) {
		for resource in resources {
			validateResourceAddition(resource)
		}
		
		self.resources = resources
		isLoaded = true
	}
	
	internal func validateResourceAddition(resource: ResourceProtocol) -> Bool {
		switch composition {
		case .Homogenous(let type):
			assert(resource.type == type, "Can not add resource with type \(resource.type) to a homogenous collection with type \(type).")
			return false
		default: ()
			return true
		}
	}
	
	
	// MARK: ifLoaded
	
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

extension ResourceCollection: SequenceType {
	public typealias Generator = IndexingGenerator<[ResourceProtocol]>
	
	public func generate() -> Generator {
		return resources.generate()
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
		
		if let nextHref = nextHref {
			dictionary.setValue(nextHref, forKey: "nextHref")
		}
		
		if let previousHref = previousHref {
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