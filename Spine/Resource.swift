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


// MARK: -

/**
*  A base recource class that provides some defaults for resources.
*  You must create custom resource classes by subclassing from Resource.
*/
public class Resource: NSObject, NSCoding, Printable {
	
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
	
	
	// MARK: Mapping data
	
	/// IDs of resources that must be linked up after mapping
	var links: [String: [String]]?
	
	/// Array of attributes that must be mapped by Spine.
	public var persistentAttributes: [Attribute] {
		return []
	}
	
	
	// MARK: Identification
	
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