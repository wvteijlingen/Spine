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
import SwiftyJSON

class SerializingTests: XCTestCase {

	class FooResource: Resource {
		dynamic var stringAttribute = "stringAttributeValue"
		dynamic var integerAttribute: NSNumber? = 10
		dynamic var floatAttribute: NSNumber? = 5.5
		dynamic var nilAttribute: AnyObject? = nil
		dynamic var dateAttribute = NSDate(timeIntervalSince1970: 0)
		dynamic var toOneAttribute = BarResource(resourceID: "2")
		dynamic var toManyAttribute = [BarResource(resourceID: "3"), BarResource(resourceID: "4")]
		
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
				"toOneAttribute": ResourceAttribute(type: .ToOne),
				"toManyAttribute": ResourceAttribute(type: .ToMany)
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
	
	
	let serializer = JSONAPISerializer()
	
	
	override func setUp() {
		super.setUp()
		serializer.registerClass(FooResource.self)
		serializer.registerClass(BarResource.self)
	}

	func testSerializeSingleResource() {
		let resource = FooResource(resourceID: "1")
		
		let serializedDocument = self.serializer.serializeResources([resource], mode: .AllAttributes)
		let JSON = JSONValue(serializedDocument)
		
		self.compareFooResource(resource, withSerialization: JSON["fooResources"])
	}
	
	
	func testSerializeMultipleResources() {
		let firstResource = FooResource(resourceID: "1")
		let secondResource = FooResource(resourceID: "2")
		
		let serializedDocument = self.serializer.serializeResources([firstResource, secondResource], mode: .AllAttributes)
		let JSON = JSONValue(serializedDocument)

		self.compareFooResource(firstResource, withSerialization: JSON["fooResources"][0])
		self.compareFooResource(secondResource, withSerialization: JSON["fooResources"][1])
	}

	private func compareFooResource(resource: FooResource, withSerialization serialization: JSONValue) {
		XCTAssertNotNil(serialization["stringAttribute"].string, "Serialization does not contain string attribute")
		XCTAssertEqual(serialization["stringAttribute"].string!, resource.stringAttribute, "Serialized string attribute is not equal.")
		
		XCTAssertNotNil(serialization["integerAttribute"].number, "Serialization does not contain integer attribute")
		XCTAssertEqual(serialization["integerAttribute"].number!, resource.integerAttribute!, "Serialized integer attribute is not equal.")
		
		XCTAssertNotNil(serialization["floatAttribute"].number, "Serialization does not contain float attribute")
		XCTAssertEqual(serialization["floatAttribute"].number!, resource.floatAttribute!, "Serialized float attribute is not equal.")
		
		XCTAssertNil(serialization["nilAttribute"].any, "Serialized nil attribute is not equal.")
		
		XCTAssertNotNil(serialization["dateAttribute"].string, "Serialization does not contain date attribute")
		XCTAssertEqual(serialization["dateAttribute"].string!, "1970-01-01T01:00:00+01:00", "Serialized date attribute is not equal.")

		XCTAssertNotNil(serialization["links"]["toOneAttribute"].string, "Serialization does not contain to one relationship")
		XCTAssertEqual(serialization["links"]["toOneAttribute"].string!, resource.toOneAttribute.resourceID!, "Serialized to one relationship is not equal.")
		
		// TODO: Check toManyAttribute
	}

}
