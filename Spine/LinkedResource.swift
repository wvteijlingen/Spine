//
//  LinkedResource.swift
//  Spine
//
//  Created by Ward van Teijlingen on 30-12-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation
import BrightFutures

public class LinkedResource: NSObject, NSCoding, Printable {
	public var isLoaded: Bool
	public var link: (href: NSURL?, type: String, id: String?)?
	public var resource: Resource? {
		didSet {
			if(oldValue?.id != self.resource?.id) {
				self.hasChanged = true
			}
		}
	}
	var hasChanged: Bool = false
	
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