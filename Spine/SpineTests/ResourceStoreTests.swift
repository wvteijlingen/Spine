//
//  ResourceStoreTests.swift
//  Spine
//
//  Created by Ward van Teijlingen on 30-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation
import XCTest
import Spine

class ResourceStoreTests: XCTestCase {
	
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
		
		let store = ResourceStore(resources: [firstResource, secondResource])
		
		XCTAssertEqual([secondResource, firstResource], store.allResources(), "Wrong value.")
	}
	
    func testAddResource() {
		let store = ResourceStore()
		let resource = FooResource(resourceID: "1")

		store.add(resource)
		XCTAssertNotNil(resource, "Nil value encountered, expected instance of FooResource with ID '1'.")
		XCTAssertEqual(resource, store.resource("fooResource", identifier: "1")!, "Wrong value encountered, expected instance of FooResource with ID '1'.")
    }
	
	func testRemoveResource() {
		let store = ResourceStore()
		let resource = FooResource(resourceID: "1")
		
		store.add(resource)
		XCTAssertEqual(resource, store.resource("fooResource", identifier: "1")!, "Wrong value encountered, expected instance of FooResource with ID '1'.")
		
		store.remove(resource)
		XCTAssertNil(store.resource("fooResource", identifier: "1"), "Wrong value encountered, expected nil.")
	}
	
	func testContainsResource() {
		let store = ResourceStore()
		let resource = FooResource(resourceID: "1")
		
		store.add(resource)
		XCTAssertTrue(store.containsResourceWithType("fooResource", identifier: "1"), "Expected true")
		
		store.remove(resource)
		XCTAssertFalse(store.containsResourceWithType("fooResource", identifier: "1"), "Expected false")
	}
	
	func testResourcesWithName() {
		let store = ResourceStore()
		let firstResource = FooResource(resourceID: "1")
		let secondResource = FooResource(resourceID: "2")
		let otherResource = BarResource(resourceID: "1")
		
		store.add(firstResource)
		store.add(secondResource)
		store.add(otherResource)
		
		XCTAssertNotNil(store.resourcesWithName("fooResource"), "Nil value encountered, expected array.")
		XCTAssertEqual([secondResource, firstResource], store.resourcesWithName("fooResource"), "Wrong value.")
	}
	
	func testAllResources() {
		let store = ResourceStore()
		let firstResource = FooResource(resourceID: "1")
		let secondResource = FooResource(resourceID: "2")
		let otherResource = BarResource(resourceID: "1")
		
		store.add(firstResource)
		store.add(secondResource)
		store.add(otherResource)
		
		XCTAssertEqual([otherResource, secondResource, firstResource], store.allResources(), "Wrong value.")
	}

}