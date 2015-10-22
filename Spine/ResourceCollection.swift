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
	
	/// The URL of the current page in this collection.
	public var resourcesURL: NSURL?
	
	/// The URL of the next page in this collection.
	public var nextURL: NSURL?
	
	/// The URL of the previous page in this collection.
	public var previousURL: NSURL?
	
	/// The loaded resources
	public internal(set) var resources: [Resource] = []
	
	
	// MARK: Initializers
	
	public init(resources: [Resource], resourcesURL: NSURL? = nil) {
		self.resources = resources
		self.resourcesURL = resourcesURL
		self.isLoaded = !resources.isEmpty
	}
	
	init(document: JSONAPIDocument) {
		self.resources = document.data ?? []
		self.resourcesURL = document.links?["self"]
		self.nextURL = document.links?["next"]
		self.previousURL = document.links?["previous"]
		self.isLoaded = true
	}
	
	
	// MARK: NSCoding
	
	public required init?(coder: NSCoder) {
		isLoaded = coder.decodeBoolForKey("isLoaded")
		resourcesURL = coder.decodeObjectForKey("resourcesURL") as? NSURL
		resources = coder.decodeObjectForKey("resources") as! [Resource]
	}
	
	public func encodeWithCoder(coder: NSCoder) {
		coder.encodeBool(isLoaded, forKey: "isLoaded")
		coder.encodeObject(resourcesURL, forKey: "resourcesURL")
		coder.encodeObject(resources, forKey: "resources")
	}
	
	
	// MARK: Subscript and count
	
	/// Returns the loaded resource at the given index.
	public subscript (index: Int) -> Resource {
		return resources[index]
	}
	
	/// Returns a loaded resource identified by the given type and id,
	/// or nil if no loaded resource was found.
	public subscript (type: String, id: String) -> Resource? {
		return resources.filter { $0.id == id && $0.resourceType == type }.first
	}
	
	/// Returns how many resources are loaded.
	public var count: Int {
		return resources.count
	}
}

extension ResourceCollection: SequenceType {
	public typealias Generator = IndexingGenerator<[Resource]>
	
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
	/// The type/id pairs of resources present in this link.
	public var linkage: [ResourceIdentifier]?
	
	/// The URL of the link object of this collection.
	public var linkURL: NSURL?
	
	/// Resources added to this linked collection, but not yet persisted.
	public internal(set) var addedResources: [Resource] = []
	
	/// Resources removed from this linked collection, but not yet persisted.
	public internal(set) var removedResources: [Resource] = []
	
	public required init() {
		super.init(resources: [], resourcesURL: nil)
	}
	
	public init(resourcesURL: NSURL?, linkURL: NSURL?, linkage: [ResourceIdentifier]?) {
		super.init(resources: [], resourcesURL: resourcesURL)
		self.linkURL = linkURL
		self.linkage = linkage
	}
	
	public convenience init(resourcesURL: NSURL?, linkURL: NSURL?, homogenousType: ResourceType, IDs: [String]) {
		self.init(resourcesURL: resourcesURL, linkURL: linkURL, linkage: IDs.map { ResourceIdentifier(type: homogenousType, id: $0) })
	}
	
	public required init?(coder: NSCoder) {
		super.init(coder: coder)
		linkURL = coder.decodeObjectForKey("linkURL") as? NSURL
		addedResources = coder.decodeObjectForKey("addedResources") as! [Resource]
		removedResources = coder.decodeObjectForKey("removedResources") as! [Resource]
		
		if let encodedLinkage = coder.decodeObjectForKey("linkage") as? [NSDictionary] {
			linkage = encodedLinkage.map { ResourceIdentifier(dictionary: $0) }
		}
	}
	
	public override func encodeWithCoder(coder: NSCoder) {
		super.encodeWithCoder(coder)
		coder.encodeObject(linkURL, forKey: "linkURL")
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
	
	- parameter resource: The resource to add.
	*/
	public func addResource(resource: Resource) {
		resources.append(resource)
		addedResources.append(resource)
		removedResources = removedResources.filter { $0 !== resource }
	}
	
	/**
	Adds the given resources to this collection. This marks the resources as added.
	
	- parameter resources: The resources to add.
	*/
	public func addResources(resources: [Resource]) {
		for resource in resources {
			addResource(resource)
		}
	}

	/**
	Removes the given resource from this collection. This marks the resource as removed.
	
	- parameter resource: The resource to remove.
	*/
	public func removeResource(resource: Resource) {
		resources = resources.filter { $0 !== resource }
		addedResources = addedResources.filter { $0 !== resource }
		removedResources.append(resource)
	}
	
	/**
	Adds the given resource to this collection, but does not mark it as added.
	
	- parameter resource: The resource to add.
	*/
	internal func addResourceAsExisting(resource: Resource) {
		resources.append(resource)
		removedResources = removedResources.filter { $0 !== resource }
		addedResources = addedResources.filter { $0 !== resource }
	}
}