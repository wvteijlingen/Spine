//
//  StoreTests.swift
//  Spine
//
//  Created by Ward van Teijlingen on 30-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation
import XCTest
import Spine

class StoreTests: XCTestCase {
	
	class FooResource: Resource {
		override var resourceType: String {
			return "fooResource"
		}
		
		override var persistentAttributes: [String: ResourceAttribute] {
			return [:]
		}
	}
	
	class BarResource: Resource {
		override var resourceType: String {
			return "barResource"
		}
		
		override var persistentAttributes: [String: ResourceAttribute] {
			return [:]
		}
	}
	
	func testInitWithResources() {
		let firstResource = FooResource(resourceID: "1")
		let secondResource = FooResource(resourceID: "2")
		let thirdResource = FooResource(resourceID: "3")
		
		let store = Store(resources: [firstResource, secondResource, thirdResource])
		
		XCTAssertEqual([firstResource, secondResource, thirdResource], store.resourcesWithName("fooResource"), "Wrong value.")
	}
	
    func testAddResource() {
		let store = Store()
		let resource = FooResource(resourceID: "1")

		store.add(resource)
		XCTAssertNotNil(resource, "Nil value encountered, expected instance of FooResource with ID '1'.")
		XCTAssertEqual(resource, store.resource("fooResource", identifier: "1")!, "Wrong value encountered, expected instance of FooResource with ID '1'.")
    }
	
	func testRemoveResource() {
		let store = Store()
		let resource = FooResource(resourceID: "1")
		
		store.add(resource)
		XCTAssertEqual(resource, store.resource("fooResource", identifier: "1")!, "Wrong value encountered, expected instance of FooResource with ID '1'.")
		
		store.remove(resource)
		XCTAssertNil(store.resource("fooResource", identifier: "1"), "Wrong value encountered, expected nil.")
	}
	
	func testContainsResource() {
		let store = Store()
		let resource = FooResource(resourceID: "1")
		
		store.add(resource)
		XCTAssertTrue(store.containsResourceWithType("fooResource", identifier: "1"), "Expected true.")
		
		store.remove(resource)
		XCTAssertFalse(store.containsResourceWithType("fooResource", identifier: "1"), "Expected false.")
	}
	
	func testResourcesWithName() {
		let store = Store()
		let firstResource = FooResource(resourceID: "1")
		let secondResource = FooResource(resourceID: "2")
		let otherResource = BarResource(resourceID: "1")
		
		store.add(firstResource)
		store.add(secondResource)
		store.add(otherResource)
		
		XCTAssertEqual([firstResource, secondResource], store.resourcesWithName("fooResource"), "Wrong value.")
		XCTAssertEqual([otherResource], store.resourcesWithName("barResource"), "Wrong value.")
	}
	
	func testAllResources() {
		let store = Store()
		let firstResource = FooResource(resourceID: "1")
		let secondResource = FooResource(resourceID: "2")
		let otherResource = BarResource(resourceID: "1")
		
		store.add(firstResource)
		store.add(secondResource)
		store.add(otherResource)
		
		let allResources = store.allResources()
		XCTAssertTrue(contains(allResources, firstResource), "Expected true.")
		XCTAssertTrue(contains(allResources, secondResource), "Expected true.")
		XCTAssertTrue(contains(allResources, otherResource), "Expected true.")
	}

}