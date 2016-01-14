//
//  ResourceCollectionTests.swift
//  Spine
//
//  Created by Ward van Teijlingen on 21-02-15.
//  Copyright (c) 2015 Ward van Teijlingen. All rights reserved.
//

import UIKit
import XCTest

class ResourceCollectionTests: XCTestCase {

	func testInitWithResourcesURLAndResources() {
		let URL = NSURL(string: "http://example.com/foos")!
		let resources = [Foo(), Bar()]
		let collection = ResourceCollection(resources: resources, resourcesURL: URL)
		
		XCTAssertNotNil(collection.resourcesURL, "Expected URL to be not nil.")
		XCTAssertEqual(collection.resourcesURL!, URL, "Expected URL to be equal.")
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
		
		XCTAssert(collection["foos", "5"] === resources[0], "Expected resource to be equal.")
		XCTAssert(collection["bars", "6"] === resources[1], "Expected resource to be equal.")
	}
	
	func testCount() {
		let resources = [Foo(), Bar()]
		let collection = ResourceCollection(resources: resources)
		
		XCTAssertEqual(collection.count, 2, "Expected count to be 2.")
	}
}


class LinkedResourceCollectionTests: XCTestCase {
	
	func testInitWithResourcesURLAndURLAndLinkage() {
		let resourcesURL = NSURL(string: "http://example.com/foos")!
		let linkURL = NSURL(string: "http://example.com/bars/1/link/foos")!
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
		let resourcesURL = NSURL(string: "http://example.com/foos")!
		let linkURL = NSURL(string: "http://example.com/bars/1/link/foos")!
		let collection = LinkedResourceCollection(resourcesURL: resourcesURL, linkURL: linkURL, homogenousType: "foos", IDs: ["1", "2"])
		
		XCTAssertNotNil(collection.resourcesURL, "Expected resources URL to be not nil.")
		XCTAssertEqual(collection.resourcesURL!, resourcesURL, "Expected resources URL to be equal.")
		
		XCTAssertNotNil(collection.linkURL, "Expected link URL to be not nil.")
		XCTAssertEqual(collection.linkURL!, linkURL, "Expected link URL to be equal.")
		
		XCTAssert(collection.linkage != nil, "Expected linkage to be not nil.")
		XCTAssertEqual(collection.linkage![0], ResourceIdentifier(type: "foos", id: "1"), "Expected first linkage item to be equal.")
		XCTAssertEqual(collection.linkage![1], ResourceIdentifier(type: "foos", id: "2"), "Expected second linkage item to be equal.")
	}
	
	func testAddAsExisting() {
		let collection = LinkedResourceCollection(resourcesURL: nil, linkURL: nil, linkage: nil)
		let foo = Foo()
		
		collection.addResourceAsExisting(foo)
		
		XCTAssert(collection.resources == [foo], "Expected collection to contain resource.")
		XCTAssert(collection.addedResources.isEmpty, "Expected addedResources to be empty.")
		XCTAssert(collection.removedResources.isEmpty, "Expected addedResources to be empty.")
	}
	
	func testAdd() {
		let collection = LinkedResourceCollection(resourcesURL: nil, linkURL: nil, linkage: nil)
		let foo = Foo()
		
		collection.addResource(foo)
		
		XCTAssert(collection.resources == [foo], "Expected collection to contain resource.")
		XCTAssert(collection.addedResources == [foo], "Expected addedResources to contain resource.")
	}

	func testAddRemoved() {
		let collection = LinkedResourceCollection(resourcesURL: nil, linkURL: nil, linkage: nil)
		let foo = Foo()

		collection.addResourceAsExisting(foo)
		collection.removeResource(foo)
		collection.addResource(foo)

		XCTAssert(collection.resources == [foo], "Expected collection to contain resource.")
		XCTAssert(collection.addedResources.isEmpty, "Expected addedResources to be empty.")
		XCTAssert(collection.removedResources.isEmpty, "Expected removedResources to be empty.")
	}

	func testRemove() {
		let collection = LinkedResourceCollection(resourcesURL: nil, linkURL: nil, linkage: nil)
		let foo = Foo()
		
		collection.addResourceAsExisting(foo)
		collection.removeResource(foo)
		
		XCTAssert(collection.resources.isEmpty, "Expected collection to be empty.")
		XCTAssert(collection.removedResources == [foo], "Expected removedResources to contain resource.")
	}

	func testRemoveAdded() {
		let collection = LinkedResourceCollection(resourcesURL: nil, linkURL: nil, linkage: nil)
		let foo = Foo()

		collection.addResource(foo)
		collection.removeResource(foo)

		XCTAssert(collection.resources.isEmpty, "Expected collection to be empty.")
		XCTAssert(collection.addedResources.isEmpty, "Expected addedResources to be empty.")
		XCTAssert(collection.removedResources.isEmpty, "Expected removedResources to be empty.")
	}
}