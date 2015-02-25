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
		let collection = ResourceCollection(resourcesURL: URL, resources: resources)
		
		XCTAssertNotNil(collection.resourcesURL, "Expected URL to be not nil.")
		XCTAssertEqual(collection.resourcesURL!, URL, "Expected URL to be equal.")
		XCTAssertTrue(collection.isLoaded, "Expected isLoaded to be true.")
		XCTAssertTrue(collection.resources == resources, "Expected resources to be true.")
	}
	
	func testIndexSubscript() {
		let resources: [ResourceProtocol] = [Foo(), Bar()]
		let collection = ResourceCollection(resources: resources)
		
		XCTAssert(collection[0] === resources[0], "Expected resource to be equal.")
		XCTAssert(collection[1] === resources[1], "Expected resource to be equal.")
	}
	
	func testTypeAndIDSubscript() {
		let foo = Foo()
		foo.id = "5"
		
		let bar = Bar()
		bar.id = "6"
		
		let resources: [ResourceProtocol] = [foo, bar]
		let collection = ResourceCollection(resources: resources)
		
		XCTAssert(collection["foos", "5"] === resources[0], "Expected resource to be equal.")
		XCTAssert(collection["bars", "6"] === resources[1], "Expected resource to be equal.")
	}
	
	func testCount() {
		let resources: [ResourceProtocol] = [Foo(), Bar()]
		let collection = ResourceCollection(resources: resources)
		
		XCTAssertEqual(collection.count, 2, "Expected count to be 2.")
	}

	func testIfLoadedIfNotLoadedWithLoadedCollection() {
		let resources = [Foo(), Bar()]
		let collection = ResourceCollection(resources: resources)
		
		var ifLoadedCalled = false
		
		collection.ifLoaded { loadedResources in
			XCTAssert(loadedResources == resources, "Expected loaded resources to be equal.")
			ifLoadedCalled = true
		}
		
		collection.ifNotLoaded {
			XCTFail("Expected ifLoaded callback to not be called.")
		}
		
		XCTAssertTrue(ifLoadedCalled, "Expected ifLoaded callback to be called.")
	}
	
	func testIfLoadedIfNotLoadedWithNotLoadedCollection() {
		let resources = [Foo(), Bar()]
		let collection = ResourceCollection(resources: resources)
		collection.isLoaded = false
		
		var ifNotLoadedCalled = false
		
		collection.ifLoaded { loadedResources in
			XCTFail("Expected ifLoaded callback to not be called.")
		}
		
		collection.ifNotLoaded {
			ifNotLoadedCalled = true
		}
		
		XCTAssertTrue(ifNotLoadedCalled, "Expected ifNotLoaded callback to be called.")
	}
}


class LinkedResourceCollectionTests: XCTestCase {
	
	func testInitWithResourcesURLAndURLAndLinkage() {
		let resourcesURL = NSURL(string: "http://example.com/foos")!
		let URL = NSURL(string: "http://example.com/bars/1/link/foos")!
		let linkage = [(type: "foos", id: "1"), (type: "bars", id: "2")]
		let collection = LinkedResourceCollection(resourcesURL: resourcesURL, URL: URL, linkage: linkage)
		
		XCTAssertNotNil(collection.resourcesURL, "Expected resources URL to be not nil.")
		XCTAssertEqual(collection.resourcesURL!, resourcesURL, "Expected resources URL to be equal.")
		
		XCTAssertNotNil(collection.URL, "Expected URL to be not nil.")
		XCTAssertEqual(collection.URL!, URL, "Expected URL to be equal.")
		
		XCTAssert(collection.linkage != nil, "Expected linkage to be not nil.")
		XCTAssert(collection.linkage![0] == linkage[0], "Expected first linkage item to be equal.")
		XCTAssert(collection.linkage![1] == linkage[1], "Expected second linkage item to be equal.")
	}
	
	func testInitWithResourcesURLAndURLAndHomogenousTypeAndLinkage() {
		let resourcesURL = NSURL(string: "http://example.com/foos")!
		let URL = NSURL(string: "http://example.com/bars/1/link/foos")!
		let collection = LinkedResourceCollection(resourcesURL: resourcesURL, URL: URL, homogenousType: "foos", linkage: ["1", "2"])
		
		XCTAssertNotNil(collection.resourcesURL, "Expected resources URL to be not nil.")
		XCTAssertEqual(collection.resourcesURL!, resourcesURL, "Expected resources URL to be equal.")
		
		XCTAssertNotNil(collection.URL, "Expected URL to be not nil.")
		XCTAssertEqual(collection.URL!, URL, "Expected URL to be equal.")
		
		XCTAssert(collection.linkage != nil, "Expected linkage to be not nil.")
		XCTAssertEqual(collection.linkage![0].type, "foos", "Expected first linkage type to be 'foos'.")
		XCTAssertEqual(collection.linkage![0].id, "1", "Expected first linkage id to be '1'.")
		XCTAssertEqual(collection.linkage![1].type, "foos", "Expected second linkage type to be 'foos'.")
		XCTAssertEqual(collection.linkage![1].id, "2", "Expected second linkage id to be '2'.")
	}
	
	func testAddAsExisting() {
		let collection = LinkedResourceCollection(resourcesURL: nil, URL: nil, linkage: nil)
		let foo = Foo()
		
		collection.addAsExisting(foo)
		
		XCTAssert(collection.resources == [foo], "")
		XCTAssert(isEmpty(collection.addedResources) , "")
	}
	
	func testAdd() {
		let collection = LinkedResourceCollection(resourcesURL: nil, URL: nil, linkage: nil)
		let foo = Foo()
		
		collection.add(foo)
		
		XCTAssert(collection.resources == [foo], "")
		XCTAssert(collection.addedResources == [foo], "")
	}
	
	func testRemove() {
		let collection = LinkedResourceCollection(resourcesURL: nil, URL: nil, linkage: nil)
		let foo = Foo()
		
		collection.add(foo)
		collection.remove(foo)
		
		XCTAssert(isEmpty(collection.resources), "")
		XCTAssert(collection.removedResources == [foo] , "")
	}
}