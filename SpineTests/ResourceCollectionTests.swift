//
//  ResourceCollectionTests.swift
//  Spine
//
//  Created by Ward van Teijlingen on 21-02-15.
//  Copyright (c) 2015 Ward van Teijlingen. All rights reserved.
//

import XCTest

class ResourceCollectionTests: XCTestCase {

	func testInitWithResourcesURLAndResources() {
		let url = URL(string: "http://example.com/foos")!
		let resources = [Foo(), Bar()]
		let collection = ResourceCollection(resources: resources, resourcesURL: url)
		
		XCTAssertNotNil(collection.resourcesURL, "Expected URL to be not nil.")
		XCTAssertEqual(collection.resourcesURL!, url, "Expected URL to be equal.")
		XCTAssertTrue(collection.isLoaded, "Expected isLoaded to be true.")
		XCTAssertTrue(collection.resources == resources, "Expected resources to be true.")
	}
	
	func testIndexSubscript() {
		let resources = [Foo(), Bar()]
		let collection = ResourceCollection(resources: resources)
		
		XCTAssert(collection[0] === resources[0], "Expected resource to be equal.")
		XCTAssert(collection[1] === resources[1], "Expected resource to be equal.")
	}
	
	func testTypeAndIDSubscript() {
		let resources = [Foo(id: "5"), Bar(id: "6")]
		let collection = ResourceCollection(resources: resources)
		
		XCTAssert(collection.resourceWithType("foos", id: "5")! === resources[0], "Expected resource to be equal.")
		XCTAssert(collection.resourceWithType("bars", id: "6")! === resources[1], "Expected resource to be equal.")
	}
	
	func testCount() {
		let resources = [Foo(), Bar()]
		let collection = ResourceCollection(resources: resources)
		
		XCTAssertEqual(collection.count, 2, "Expected count to be 2.")
	}
	
	func testAppendResource() {
		let foo = Foo(id: "1")
		let collection = ResourceCollection(resources: [])
		
		collection.appendResource(foo)
		XCTAssertEqual(collection.resources, [foo], "Expected resources to be equal.")
	}
}


class LinkedResourceCollectionTests: XCTestCase {
	
	func testInitWithResourcesURLAndURLAndLinkage() {
		let resourcesURL = URL(string: "http://example.com/foos")!
		let linkURL = URL(string: "http://example.com/bars/1/link/foos")!
		let linkage = [ResourceIdentifier(type: "foos", id: "1"), ResourceIdentifier(type: "bars", id: "2")]
		let collection = LinkedResourceCollection(resourcesURL: resourcesURL, linkURL: linkURL, linkage: linkage)
		
		XCTAssertNotNil(collection.resourcesURL, "Expected resources URL to be not nil.")
		XCTAssertEqual(collection.resourcesURL!, resourcesURL, "Expected resources URL to be equal.")
		
		XCTAssertNotNil(collection.linkURL, "Expected link URL to be not nil.")
		XCTAssertEqual(collection.linkURL!, linkURL, "Expected link URL to be equal.")
		
		XCTAssert(collection.linkage != nil, "Expected linkage to be not nil.")
		XCTAssertEqual(collection.linkage![0], linkage[0], "Expected first linkage item to be equal.")
		XCTAssertEqual(collection.linkage![1], linkage[1], "Expected second linkage item to be equal.")
	}
	
	func testInitWithResourcesURLAndURLAndHomogenousTypeAndLinkage() {
		let resourcesURL = URL(string: "http://example.com/foos")!
		let linkURL = URL(string: "http://example.com/bars/1/link/foos")!
		let collection = LinkedResourceCollection(resourcesURL: resourcesURL, linkURL: linkURL, linkage: ["1", "2"].map { ResourceIdentifier(type: "foos", id: $0) })
		
		XCTAssertNotNil(collection.resourcesURL, "Expected resources URL to be not nil.")
		XCTAssertEqual(collection.resourcesURL!, resourcesURL, "Expected resources URL to be equal.")
		
		XCTAssertNotNil(collection.linkURL, "Expected link URL to be not nil.")
		XCTAssertEqual(collection.linkURL!, linkURL, "Expected link URL to be equal.")
		
		XCTAssert(collection.linkage != nil, "Expected linkage to be not nil.")
		XCTAssertEqual(collection.linkage![0], ResourceIdentifier(type: "foos", id: "1"), "Expected first linkage item to be equal.")
		XCTAssertEqual(collection.linkage![1], ResourceIdentifier(type: "foos", id: "2"), "Expected second linkage item to be equal.")
	}
	
	func testAppendResource() {
		let collection = LinkedResourceCollection(resourcesURL: nil, linkURL: nil, linkage: nil)
		let foo = Foo(id: "1")
		
		collection.appendResource(foo)
		
		XCTAssert(collection.resources == [foo], "Expected collection to contain resource.")
		XCTAssert(collection.addedResources.isEmpty, "Expected addedResources to be empty.")
		XCTAssert(collection.removedResources.isEmpty, "Expected addedResources to be empty.")
	}
	
	func testLinkResource() {
		let collection = LinkedResourceCollection(resourcesURL: nil, linkURL: nil, linkage: nil)
		let foo = Foo(id: "1")
		
		collection.linkResource(foo)
		
		XCTAssert(collection.resources == [foo], "Expected collection to contain resource.")
		XCTAssert(collection.addedResources == [foo], "Expected addedResources to contain resource.")
	}

	func testLinkUnlinked() {
		let collection = LinkedResourceCollection(resourcesURL: nil, linkURL: nil, linkage: nil)
		let foo = Foo(id: "1")

		collection.appendResource(foo)
		collection.unlinkResource(foo)
		collection.linkResource(foo)

		XCTAssert(collection.resources == [foo], "Expected collection to contain resource.")
		XCTAssert(collection.addedResources.isEmpty, "Expected addedResources to be empty.")
		XCTAssert(collection.removedResources.isEmpty, "Expected removedResources to be empty.")
	}

	func testUnlink() {
		let collection = LinkedResourceCollection(resourcesURL: nil, linkURL: nil, linkage: nil)
		let foo = Foo(id: "1")
		
		collection.appendResource(foo)
		collection.unlinkResource(foo)
		
		XCTAssert(collection.resources.isEmpty, "Expected collection to be empty.")
		XCTAssert(collection.removedResources == [foo], "Expected removedResources to contain resource.")
	}

	func testUnlinkLinked() {
		let collection = LinkedResourceCollection(resourcesURL: nil, linkURL: nil, linkage: nil)
		let foo = Foo(id: "1")

		collection.linkResource(foo)
		collection.unlinkResource(foo)

		XCTAssert(collection.resources.isEmpty, "Expected collection to be empty.")
		XCTAssert(collection.addedResources.isEmpty, "Expected addedResources to be empty.")
		XCTAssert(collection.removedResources.isEmpty, "Expected removedResources to be empty.")
	}
}
