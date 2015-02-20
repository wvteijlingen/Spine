//
//  SerializingTests.swift
//  Spine
//
//  Created by Ward van Teijlingen on 06-09-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation
import XCTest
import SwiftyJSON

class SerializingTests: XCTestCase {

	class Foo: Resource {
		dynamic var stringAttribute: String?
		dynamic var integerAttribute: NSNumber?
		dynamic var floatAttribute: NSNumber?
		dynamic var booleanAttribute: NSNumber?
		dynamic var nilAttribute: AnyObject?
		dynamic var dateAttribute: NSDate?
		dynamic var toOneAttribute: Bar?
		dynamic var toManyAttribute: LinkedResourceCollection?
		
		override class var resourceType: String {
			return "foos"
		}
		
		override var attributes: [Attribute] {
			return attributesFromDictionary([
				"stringAttribute": PropertyAttribute(),
				"integerAttribute": PropertyAttribute(),
				"floatAttribute": PropertyAttribute(),
				"booleanAttribute": PropertyAttribute(),
				"nilAttribute": PropertyAttribute(),
				"dateAttribute": DateAttribute(),
				"toOneAttribute": ToOneAttribute(Bar.resourceType),
				"toManyAttribute": ToManyAttribute(Bar.resourceType)
			])
		}
	}
	
	class Bar: Resource {
		override class var resourceType: String {
			return "bars"
		}
		
		override var attributes: [Attribute] {
			return []
		}
	}
	
	
	let serializer = JSONSerializer()
	
	override func setUp() {
		super.setUp()
		serializer.resourceFactory.registerResource(Foo.resourceType) { Foo() }
		serializer.resourceFactory.registerResource(Bar.resourceType) { Bar() }
	}
	
	func compareAttributesOfFooResource(foo: Foo, withJSON json: JSON) {
			XCTAssertEqual(foo.stringAttribute!, json["stringAttribute"].stringValue, "Deserialized string attribute is not equal.")
			XCTAssertEqual(foo.integerAttribute!, json["integerAttribute"].intValue, "Deserialized integer attribute is not equal.")
			XCTAssertEqual(foo.floatAttribute!, json["floatAttribute"].floatValue, "Deserialized float attribute is not equal.")
			XCTAssertEqual(foo.booleanAttribute!, json["integerAttribute"].boolValue, "Deserialized boolean attribute is not equal.")
			XCTAssertNil(foo.nilAttribute, "Deserialized nil attribute is not equal.")
			XCTAssertEqual(foo.dateAttribute!, NSDate(timeIntervalSince1970: 0), "Deserialized date attribute is not equal.")
	}
	
	func testDeserializeSinglePrimaryResource() {
		let path = testBundle.URLForResource("SingleFoo", withExtension: "json")!
		let data = NSData(contentsOfURL: path)!
		
		let deserialisationResult = serializer.deserializeData(data, mappingTargets: nil)
		let json = JSON(data: data)
		
		switch deserialisationResult {
		case .Success(let resources, let pagination):
			XCTAssertEqual(resources.count, 1, "Deserialized resources count not equal.")
			XCTAssert(resources.first is Foo, "Deserialized resource should be of class 'Foo'.")
			let foo = resources.first as Foo
			
			// Attributes
			compareAttributesOfFooResource(foo, withJSON: json["data"])
			
			// To one link
			XCTAssertNotNil(foo.toOneAttribute, "Deserialized linked resource should not be nil.")
			let bar = foo.toOneAttribute!
			XCTAssertEqual(bar.URL!.absoluteString!, json["data"]["links"]["toOneAttribute"]["resource"].stringValue, "Deserialized link URL is not equal.")
			XCTAssertFalse(bar.isLoaded, "Deserialized link isLoaded is not false.")
			
			// To many link
			XCTAssertNotNil(foo.toManyAttribute, "Deserialized linked resources should not be nil.")
			let barCollection = foo.toManyAttribute!
			XCTAssertEqual(barCollection.URL!.absoluteString!, json["data"]["links"]["toManyAttribute"]["self"].stringValue, "Deserialized link URL is not equal.")
			XCTAssertEqual(barCollection.resourcesURL!.absoluteString!, json["data"]["links"]["toManyAttribute"]["resource"].stringValue, "Deserialized resource URL is not equal.")
			XCTAssertFalse(barCollection.isLoaded, "Deserialized link isLoaded is not false.")
			
		default: ()
			XCTFail("Deserialisation was not .Success")
		}
	}
	
	func testDeserializeMultiplePrimaryResources() {
		let path = testBundle.URLForResource("MultipleFoos", withExtension: "json")!
		let data = NSData(contentsOfURL: path)!
		
		let deserialisationResult = serializer.deserializeData(data, mappingTargets: nil)
		let json = JSON(data: data)
		
		switch deserialisationResult {
		case .Success(let resources, let pagination):
			XCTAssertEqual(resources.count, 2, "Deserialized resources count not equal.")
			
			for (index, resource) in enumerate(resources) {
				XCTAssert(resource is Foo, "Deserialized resource should be of class 'Foo'.")
				let foo = resource as Foo
				
				// Attributes
				compareAttributesOfFooResource(foo, withJSON: json["data"][index])
				
				// To one link
				XCTAssertNotNil(foo.toOneAttribute, "Deserialized linked resource should not be nil.")
				let bar = foo.toOneAttribute!
				XCTAssertEqual(bar.URL!.absoluteString!, "http://example.com/bars/1", "Deserialized link URL is not equal.")
				XCTAssertFalse(bar.isLoaded, "Deserialized link isLoaded is not false.")
				
				// To many link
				XCTAssertNotNil(foo.toManyAttribute, "Deserialized linked resources should not be nil.")
				let barCollection = foo.toManyAttribute!
				XCTAssertEqual(barCollection.URL!.absoluteString!, "http://example.com/foos/1/links/toManyAttribute", "Deserialized link URL is not equal.")
				XCTAssertEqual(barCollection.resourcesURL!.absoluteString!, "http://example.com/bars/1/bars", "Deserialized resource URL is not equal.")
				XCTAssertFalse(barCollection.isLoaded, "Deserialized link isLoaded is not false.")
			}
			
		default: ()
		XCTFail("Deserialisation was not .Success")
		}
	}
//
//	func testSerializeSingleResource() {
//		let resource = FooResource(resourceID: "1")
//		
//		let serializedDocument = self.serializer.serializeResources([resource], mode: .AllAttributes)
//		let JSON = JSONValue(serializedDocument)
//		
//		self.compareFooResource(resource, withSerialization: JSON["fooResources"])
//	}
//	
//	
//	func testSerializeMultipleResources() {
//		let firstResource = FooResource(resourceID: "1")
//		let secondResource = FooResource(resourceID: "2")
//		
//		let serializedDocument = self.serializer.serializeResources([firstResource, secondResource], mode: .AllAttributes)
//		let JSON = JSONValue(serializedDocument)
//
//		self.compareFooResource(firstResource, withSerialization: JSON["fooResources"][0])
//		self.compareFooResource(secondResource, withSerialization: JSON["fooResources"][1])
//	}
//
//	private func compareFooResource(resource: FooResource, withSerialization serialization: JSONValue) {
//		XCTAssertNotNil(serialization["stringAttribute"].string, "Serialization does not contain string attribute")
//		XCTAssertEqual(serialization["stringAttribute"].string!, resource.stringAttribute, "Serialized string attribute is not equal.")
//		
//		XCTAssertNotNil(serialization["integerAttribute"].number, "Serialization does not contain integer attribute")
//		XCTAssertEqual(serialization["integerAttribute"].number!, resource.integerAttribute!, "Serialized integer attribute is not equal.")
//		
//		XCTAssertNotNil(serialization["floatAttribute"].number, "Serialization does not contain float attribute")
//		XCTAssertEqual(serialization["floatAttribute"].number!, resource.floatAttribute!, "Serialized float attribute is not equal.")
//		
//		XCTAssertNil(serialization["nilAttribute"].any, "Serialized nil attribute is not equal.")
//		
//		XCTAssertNotNil(serialization["dateAttribute"].string, "Serialization does not contain date attribute")
//		XCTAssertEqual(serialization["dateAttribute"].string!, "1970-01-01T01:00:00+01:00", "Serialized date attribute is not equal.")
//
//		XCTAssertNotNil(serialization["links"]["toOneAttribute"].string, "Serialization does not contain to one relationship")
//		XCTAssertEqual(serialization["links"]["toOneAttribute"].string!, resource.toOneAttribute.resourceID!, "Serialized to one relationship is not equal.")
//		
//		// TODO: Check toManyAttribute
//	}

}
