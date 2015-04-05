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
A ResourceCollection represents a collection of resources.
It contains a URL where the resources can be fetched.
For collections that can be paginated, pagination data is stored as well.
*/
public class ResourceCollection: NSObject, NSCoding {
	/// Whether the resources for this collection are loaded
	public var isLoaded: Bool
	
	/// The URL where the resources in this collection can be fetched
	public var resourcesURL: NSURL?
	
	/// The loaded resources
	public internal(set) var resources: [ResourceProtocol] = []
	
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
	}
	
	public func encodeWithCoder(coder: NSCoder) {
		coder.encodeBool(isLoaded, forKey: "isLoaded")
		coder.encodeObject(resourcesURL, forKey: "resourcesURL")
		coder.encodeObject(resources, forKey: "resources")
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

extension ResourceCollection: SequenceType {
	public typealias Generator = IndexingGenerator<[ResourceProtocol]>
	
	public func generate() -> Generator {
		return resources.generate()
	}
}

/**
A LinkedResourceCollection represents a collection of resources that is linked from another resource.
The main differences with ResourceCollection is that it is mutable,
and the addition of `linkage`, and a self `URL` property.

A LinkedResourceCollection keeps track of resources that are added to and removed from the collection.
This allows Spine to make partial updates to the collection when it is persisted.
*/
public class LinkedResourceCollection: ResourceCollection {
	/// The self URL of this link.
	public var URL: NSURL?
	
	/// The type/id pairs of resources present in this link.
	public var linkage: [ResourceIdentifier]?
	
	/// Resources added to this linked collection, but not yet persisted.
	public internal(set) var addedResources: [ResourceProtocol] = []
	
	/// Resources removed from this linked collection, but not yet persisted.
	public internal(set) var removedResources: [ResourceProtocol] = []
	
	public required init() {
		super.init(resourcesURL: nil, resources: [])
	}
	
	public init(resourcesURL: NSURL?, URL: NSURL?, linkage: [ResourceIdentifier]?) {
		super.init(resourcesURL: resourcesURL, resources: [])
		self.URL = URL
		self.linkage = linkage
	}
	
	public convenience init(resourcesURL: NSURL?, URL: NSURL?, homogenousType: ResourceType, linkage: [String]?) {
		self.init(resourcesURL: resourcesURL, URL: URL, linkage: linkage?.map { ResourceIdentifier(type: homogenousType, id: $0) })
	}
	
	public required init(coder: NSCoder) {
		super.init(coder: coder)
		URL = coder.decodeObjectForKey("URL") as? NSURL
		addedResources = coder.decodeObjectForKey("addedResources") as [ResourceProtocol]
		removedResources = coder.decodeObjectForKey("removedResources") as [ResourceProtocol]
		
		if let encodedLinkage = coder.decodeObjectForKey("linkage") as? [NSDictionary] {
			linkage = encodedLinkage.map { ResourceIdentifier(dictionary: $0) }
		}
	}
	
	public override func encodeWithCoder(coder: NSCoder) {
		super.encodeWithCoder(coder)
		coder.encodeObject(URL, forKey: "URL")
		coder.encodeObject(addedResources, forKey: "addedResources")
		coder.encodeObject(removedResources, forKey: "removedResources")
		
		if let linkage = linkage {
			let encodedLinkage = linkage.map { $0.toDictionary() }
			coder.encodeObject(encodedLinkage, forKey: "linkage")
		}
	}
	
	// MARK: Mutators
	
	/**
	Adds the given resource to this collection. This marks the resource as added.
	
	:param: resource The resource to add.
	*/
	public func addResource(resource: ResourceProtocol) {
		resources.append(resource)
		addedResources.append(resource)
		removedResources = removedResources.filter { $0 !== resource }
	}
	
	/**
	Adds the given resources to this collection. This marks the resources as added.
	
	:param: resources The resources to add.
	*/
	public func addResources(resources: [ResourceProtocol]) {
		for resource in resources {
			addResource(resource)
		}
	}

	/**
	Removes the given resource from this collection. This marks the resource as removed.
	
	:param: resource The resource to remove.
	*/
	public func removeResource(resource: ResourceProtocol) {
		resources = resources.filter { $0 !== resource }
		addedResources = addedResources.filter { $0 !== resource }
		removedResources.append(resource)
	}
	
	/**
	Adds the given resource to this collection, but does not mark it as added.
	
	:param: resource The resource to add.
	*/
	internal func addResourceAsExisting(resource: ResourceProtocol) {
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
		addResource(newElement)
	}
	
	public func extend<S : SequenceType where S.Generator.Element == ResourceProtocol>(seq: S) {
		for element in seq {
			addResource(element)
		}
	}
}