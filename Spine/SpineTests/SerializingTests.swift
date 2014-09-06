//
//  SerializingTests.swift
//  Spine
//
//  Created by Ward van Teijlingen on 06-09-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation
import XCTest
import Spine

class SerializingTests: XCTestCase {

	class FooResource: Resource {
		var stringAttribute = "stringAttributeValue"
		var integerAttribute: Int = 10
		var floatAttribute: Float = 5.5
		var nilAttribute: AnyObject? = nil
		var dateAttribute = NSDate(timeIntervalSince1970: 0)
		var toOneAttribute = BarResource(resourceID: "2")
		
		override var resourceType: String {
			return "fooResources"
		}
		
		override var persistentAttributes: [String: ResourceAttribute] {
			return [
				"stringAttribute": ResourceAttribute(type: .Property),
				"integerAttribute": ResourceAttribute(type: .Property),
				"floatAttribute": ResourceAttribute(type: .Property),
				"nilAttribute": ResourceAttribute(type: .Property),
				"dateAttribute": ResourceAttribute(type: .Date),
				"toOneAttribute": ResourceAttribute(type: .ToOne)
			]
		}
	}
	
	class BarResource: Resource {
		override var resourceType: String {
			return "barResources"
		}
		
		override var persistentAttributes: [String: ResourceAttribute] {
			return [:]
		}
	}
	
	let serializer = Serializer()
	
	override func setUp() {
		super.setUp()
		serializer.registerClass(FooResource.self)
	}
	
	override func tearDown() {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
		super.tearDown()
	}

	func testSerializeSingleResource() {
		let resource = FooResource(resourceID: "1")
		let serialized = self.serializer.serializeResources([resource])
		
		XCTAssertNotNil(serialized["fooResources"], "Serialization does not contain root element 'fooResources'.")
		XCTAssertEqual(serialized["fooResources"]!.count, 1, "Serialization does not contain one resource.")
		
		self.compareFooResource(resource, withSerialization: serialized["fooResources"]!.first!)
	}
	
	func testSerializeMultipleResources() {
		let firstResource = FooResource(resourceID: "1")
		let secondResource = FooResource(resourceID: "1")
		let serialized = self.serializer.serializeResources([firstResource, secondResource])
		
		XCTAssertNotNil(serialized["fooResources"], "Serialization does not contain root element 'fooResources'.")
		XCTAssertEqual(serialized["fooResources"]!.count, 2, "Serialization does not contain two resources.")
		
		let serializedResources: [ResourceRepresentation] = serialized["fooResources"]!
		
		self.compareFooResource(firstResource, withSerialization: serializedResources[0])
		self.compareFooResource(firstResource, withSerialization: serializedResources[1])
	}
	
	/*
	 * FIXME: This crashes Xcode 7 beta 7
	 *
	func testSerializeToOneRelationship() {
		let resource = FooResource(resourceID: "1")
		let serialized = self.serializer.serializeResources([resource])
		
		XCTAssertNotNil(serialized["fooResources"], "Serialization does not contain root element 'fooResources'.")
		XCTAssertEqual(serialized["fooResources"]!.count, 1, "Serialization does not contain one resource.")
		
		if let serializedResources = serialized["fooResources"] {
			if let serializedLinks = serializedResources[0]["links"] {
				if let serializedToOneAttribute = serializedLinks["toOneAttribute"] {
					XCTAssertEqual(serializedToOneAttribute as [Int], ["2"], "Serialized to-one attribute is not equal.")
				}
			}
		}
	}
	*/
	
	private func compareFooResource(resource: FooResource, withSerialization serialization: ResourceRepresentation) {
		let serializedStringAttribute = (serialization["stringAttribute"]! as String)
		let serializedIntegerAttribute = (serialization["integerAttribute"]! as Int)
		let serializedFloatAttribute = (serialization["floatAttribute"]! as Float)
		let serializedNilAttribute = (serialization["nilAttribute"]! as NSNull)
		let serializedDateAttribute = (serialization["dateAttribute"]! as String)
		
		XCTAssertEqual(serializedStringAttribute, resource.stringAttribute, "Serialized string attribute is not equal.")
		XCTAssertEqual(serializedIntegerAttribute, resource.integerAttribute, "Serialized integer attribute is not equal.")
		XCTAssertEqual(serializedFloatAttribute, resource.floatAttribute, "Serialized float attribute is not equal.")
		XCTAssertEqual(serializedNilAttribute, NSNull(), "Serialized nil attribute is not equal.")
		XCTAssertEqual(serializedDateAttribute, "1970-01-01T01:00:00+01:00", "Serialized date attribute is not equal.")
	}

}
