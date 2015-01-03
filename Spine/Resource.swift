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
*  A base recource class that provides some defaults for resources.
*  You must create custom resource classes by subclassing from Resource.
*/
public class Resource: NSObject, NSCoding, Printable {
	public class var type: String { return "_unknown_type" }
	public var id: String?
	public var href: NSURL?
	public var isLoaded: Bool = false
	
	
	// MARK: Initializers
	
	// This is needed for the dynamic instantiation based on the metatype
	required override public init() {
		super.init()
	}
	
	public init(id: String?, href: NSURL?) {
		super.init()
		self.id = id
		self.href = href
	}
	

	// MARK: NSCoding protocol
	
	public required init(coder: NSCoder) {
		super.init()
		self.id = coder.decodeObjectForKey("id") as? String
		self.href = coder.decodeObjectForKey("href") as? NSURL
		self.isLoaded = coder.decodeBoolForKey("isLoaded")

	}
	
	public func encodeWithCoder(coder: NSCoder) {
		coder.encodeObject(self.id, forKey: "id")
		coder.encodeObject(self.href, forKey: "href")
		coder.encodeBool(self.isLoaded, forKey: "isLoaded")
	}
	
	
	// MARK: Mapping data
	
	/// Array of attributes that must be mapped by Spine.
	public var persistentAttributes: [String: Attribute] {
		return [:]
	}
	
	var attributes: [Attribute] {
		return map(self.persistentAttributes) { (name, attribute) in
			attribute.name = name
			return attribute
		}
	}
	
	
	// MARK: Persisting
	
	/**
	Saves this resource asynchronously.
	
	:returns: A future of this resource.
	*/
	public func save() -> Future<Resource> {
		return Spine.sharedInstance.save(self)
	}
	
	/**
	Deletes this resource asynchronously.
	
	:returns: A void future.
	*/
	public func delete() -> Future<Void> {
		return Spine.sharedInstance.delete(self)
	}
	
	
	// MARK: Printable protocol
	
	override public var description: String {
		return "\(self.dynamicType.type)[\(self.id)]"
	}
}

// MARK: - Ensuring

public func ensure<T: Resource>(resource: T) -> Future<T> {
	let query = Query(resource: resource)
	return ensure(resource, query)
}

public func ensure<T: Resource>(resource: T, queryCallback: (Query<T>) -> Void) -> Future<T> {
	let query = Query(resource: resource)
	queryCallback(query)
	return ensure(resource, query)
}

func ensure<T: Resource>(resource: T, query: Query<T>) -> Future<T> {
	let promise = Promise<(T)>()
	
	if resource.isLoaded {
		promise.success(resource)
	} else {
		Spine.sharedInstance.fetch(query, mapOnto: [resource]).onSuccess { resources in
			promise.success(resource)
			}.onFailure { error in
				promise.error(error)
		}
	}
	
	return promise.future
}