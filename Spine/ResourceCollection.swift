//
//  ResourceCollection.swift
//  Spine
//
//  Created by Ward van Teijlingen on 30-12-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation
import BrightFutures

/// A ResourceCollection represents a collection of resources.
public class ResourceCollection: NSObject, NSCoding {
	/// Whether the resources for this collection are loaded.
	public var isLoaded: Bool = false
	
	/// The URL of the current page in this collection.
	public var resourcesURL: URL?
	
	/// The URL of the next page in this collection.
	public var nextURL: URL?
	
	/// The URL of the previous page in this collection.
	public var previousURL: URL?
	
	/// The loaded resources
	public internal(set) var resources: [Resource] = []
	
	
	// MARK: Initializers
	
	public override init() {}
	
	public init(resources: [Resource], resourcesURL: URL? = nil) {
		self.resources = resources
		self.resourcesURL = resourcesURL
		self.isLoaded = !resources.isEmpty
	}
	
	init(document: JSONAPIDocument) {
		self.resources = document.data ?? []
		self.resourcesURL = document.links?["self"] as URL?
		self.nextURL = document.links?["next"] as URL?
		self.previousURL = document.links?["previous"] as URL?
		self.isLoaded = true
	}
	
	
	// MARK: NSCoding
	
	public required init?(coder: NSCoder) {
		isLoaded = coder.decodeBool(forKey: "isLoaded")
		resourcesURL = coder.decodeObject(forKey: "resourcesURL") as? URL
		nextURL = coder.decodeObject(forKey: "nextURL") as? URL
		previousURL = coder.decodeObject(forKey: "previousURL") as? URL
		resources = coder.decodeObject(forKey: "resources") as! [Resource]
	}
	
	public func encode(with coder: NSCoder) {
		coder.encode(isLoaded, forKey: "isLoaded")
		coder.encode(resourcesURL, forKey: "resourcesURL")
		coder.encode(nextURL, forKey: "nextURL")
		coder.encode(previousURL, forKey: "previousURL")
		coder.encode(resources, forKey: "resources")
	}
	
	
	// MARK: Subscript and count
	
	/// Returns the loaded resource at the given index.
	public subscript (index: Int) -> Resource {
		return resources[index]
	}
	
	/// Returns how many resources are loaded.
	public var count: Int {
		return resources.count
	}
	
	/// Returns a resource identified by the given type and id,
	/// or nil if no resource was found.
	public func resourceWithType(_ type: ResourceType, id: String) -> Resource? {
		return resources.filter { $0.id == id && $0.resourceType == type }.first
	}
	
	// MARK: Mutators
	
	/// Append `resource` to the collection.
	public func appendResource(_ resource: Resource) {
		resources.append(resource)
	}
	
	/// Append `resources` to the collection.
	public func appendResources(_ resources: [Resource]) {
		for resource in resources {
			appendResource(resource)
		}
	}

	/// Remove `resource` from the collection.
	open func removeResource(_ resource: Resource) {
		resources = resources.filter { $0 !== resource }
	}
	
	/// Remove `resources` from the collection.
	open func removeResources(_ resources: [Resource]) {
		for resource in resources {
			removeResource(resource)
		}
	}
}

extension ResourceCollection: Sequence {
	public typealias Iterator = IndexingIterator<[Resource]>
	
	public func makeIterator() -> Iterator {
		return resources.makeIterator()
	}
}

/// `LinkedResourceCollection` represents a collection of resources that is linked from another resource.
/// On top of `ResourceCollection` it offers mutability, `linkage` and a self `URL` properties.
///
/// A `LinkedResourceCollection` keeps track of resources that are linked and unlinked from the collection.
/// This allows Spine to make partial updates to the collection when it the parent resource is persisted.
public class LinkedResourceCollection: ResourceCollection {
	/// The type/id pairs of resources present in this link.
	public var linkage: [ResourceIdentifier]?
	
	/// The URL of the link object of this collection.
	public var linkURL: URL?
	
	/// Resources added to this linked collection, but not yet persisted.
	public internal(set) var addedResources: [Resource] = []
	
	/// Resources removed from this linked collection, but not yet persisted.
	public internal(set) var removedResources: [Resource] = []
	
	public init(resourcesURL: URL?, linkURL: URL?, linkage: [ResourceIdentifier]?) {
		super.init(resources: [], resourcesURL: resourcesURL)
		self.linkURL = linkURL
		self.linkage = linkage
	}
	
	public required init?(coder: NSCoder) {
		super.init(coder: coder)
		linkURL = coder.decodeObject(forKey: "linkURL") as? URL
		addedResources = coder.decodeObject(forKey: "addedResources") as! [Resource]
		removedResources = coder.decodeObject(forKey: "removedResources") as! [Resource]
		
		if let encodedLinkage = coder.decodeObject(forKey: "linkage") as? [NSDictionary] {
			linkage = encodedLinkage.map { ResourceIdentifier(dictionary: $0) }
		}
	}
	
	public override func encode(with coder: NSCoder) {
		super.encode(with: coder)
		coder.encode(linkURL, forKey: "linkURL")
		coder.encode(addedResources, forKey: "addedResources")
		coder.encode(removedResources, forKey: "removedResources")
		
		if let linkage = linkage {
			let encodedLinkage = linkage.map { $0.toDictionary() }
			coder.encode(encodedLinkage, forKey: "linkage")
		}
	}
	
	// MARK: Mutators
	
	/// Link `resource` to the parent resource by appending it to the collection.
	/// This marks the resource as newly linked. The relationship will be persisted when
	/// the parent resource is saved.
	public func linkResource(_ resource: Resource) {
		assert(resource.id != nil, "Cannot link resource that hasn't been persisted yet.")
		
		resources.append(resource)
		
		if let index = removedResources.index(of: resource) {
			removedResources.remove(at: index)
		} else {
			addedResources.append(resource)
		}
	}
	
	/// Unlink `resource` from the parent resource by removing it from the collection.
	/// This marks the resource as unlinked. The relationship will be persisted when
	/// the parent resource is saved.
	public func unlinkResource(_ resource: Resource) {
		assert(resource.id != nil, "Cannot unlink resource that hasn't been persisted yet.")
		
		resources = resources.filter { $0 !== resource }
		
		if let index = addedResources.index(of: resource) {
			addedResources.remove(at: index)
		} else {
			removedResources.append(resource)
		}
	}
	
	/// Link `resources` to the parent resource by appending them to the collection.
	/// This marks the resources as newly linked. The relationship will be persisted when
	/// the parent resource is saved.
	public func linkResources(_ resources: [Resource]) {
		for resource in resources {
			linkResource(resource)
		}
	}
	
	/// Unlink `resources` from the parent resource by removing then from the collection.
	/// This marks the resources as unlinked. The relationship will be persisted when
	/// the parent resource is saved.
	public func unlinkResources(_ resources: [Resource]) {
		for resource in resources {
			unlinkResource(resource)
		}
	}
	
	/// Append `resource` to the collection as if it is already linked.
	/// If it was previously linked or unlinked, this status will be removed.
	public override func appendResource(_ resource: Resource) {
		super.appendResource(resource)
		removedResources = removedResources.filter { $0 !== resource }
		addedResources = addedResources.filter { $0 !== resource }
	}
	
	/// Append `resources` to the collection as if they are already linked.
	/// If a resource was previously linked or unlinked, this status will be removed.
	public override func appendResources(_ resources: [Resource]) {
		for resource in resources {
			appendResource(resource)
		}
	}
}
