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

class SerializerTests: XCTestCase {
	let serializer = JSONSerializer()
	
	override func setUp() {
		super.setUp()
		serializer.resourceFactory.registerResource(Foo.resourceType) { Foo() }
		serializer.resourceFactory.registerResource(Bar.resourceType) { Bar() }
	}
}

class SerializingTests: SerializerTests {
	
	let foo: Foo = Foo(id: "1")
	
	override func setUp() {
		super.setUp()
		foo.stringAttribute = "stringAttribute"
		foo.integerAttribute = 10
		foo.floatAttribute = 5.5
		foo.booleanAttribute = true
		foo.nilAttribute = nil
		foo.dateAttribute = NSDate(timeIntervalSince1970: 0)
		foo.toOneAttribute = Bar(id: "10")
		foo.toManyAttribute = LinkedResourceCollection(resourcesURL: nil, URL: nil, homogenousType: "bars", linkage: nil)
		foo.toManyAttribute?.addResourceAsExisting(Bar(id: "11"))
		foo.toManyAttribute?.addResourceAsExisting(Bar(id: "12"))
	}
	
	func serializedJSONWithOptions(options: SerializationOptions) -> JSON {
		let serializedData = serializer.serializeResources([foo], options: options)
		return JSON(data: serializedData)
	}
	
	func testSerializeSingleResourceAttributes() {
		let json = serializedJSONWithOptions(SerializationOptions())
		
		XCTAssertEqual(json["data"]["id"].stringValue, foo.id!, "Serialized id is not equal.")
		XCTAssertEqual(json["data"]["type"].stringValue, foo.type, "Serialized type is not equal.")
		XCTAssertEqual(json["data"]["integerAttribute"].intValue, foo.integerAttribute!, "Serialized integer is not equal.")
		XCTAssertEqual(json["data"]["floatAttribute"].floatValue, foo.floatAttribute!, "Serialized float is not equal.")
		XCTAssertTrue(json["data"]["booleanAttribute"].boolValue, "Serialized boolean is not equal.")
		XCTAssertNotNil(json["data"]["nilAttribute"].null, "Serialized nil is not equal.")
		XCTAssertEqual(json["data"]["dateAttribute"].stringValue, "1970-01-01T01:00:00+01:00", "Serialized date is not equal.")
	}
	
	func testSerializeSingleResourceToOneRelationships() {
		let json = serializedJSONWithOptions(SerializationOptions(includeToOne: true))
		
		XCTAssertEqual(json["data"]["links"]["toOneAttribute"]["id"].stringValue, foo.toOneAttribute!.id!, "Serialized to-one id is not equal")
		XCTAssertEqual(json["data"]["links"]["toOneAttribute"]["type"].stringValue, Bar.resourceType, "Serialized to-one type is not equal")
	}
	
	func testSerializeSingleResourceToManyRelationships() {
		let json = serializedJSONWithOptions(SerializationOptions(includeToMany: true, includeToOne: true))
		
		XCTAssertEqual(json["data"]["links"]["toManyAttribute"]["ids"].arrayObject as [String], ["11", "12"], "Serialized to-many ids are not equal")
		XCTAssertEqual(json["data"]["links"]["toManyAttribute"]["type"].stringValue, Bar.resourceType, "Serialized to-many type is not equal")
	}
	
	func testSerializeSingleResourceWithoutID() {
		let json = serializedJSONWithOptions(SerializationOptions(includeID: false, includeToMany: true, includeToOne: true))
		
		XCTAssertNotNil(json["data"]["id"].error, "Expected serialized id to be absent.")
	}
	
	func testSerializeSingleResourceWithoutToOneRelationships() {
		let json = serializedJSONWithOptions(SerializationOptions(includeToMany: true, includeToOne: false))

		XCTAssertNotNil(json["data"]["links"]["toOneAttribute"].error, "Expected serialized to-one to be absent")
	}
	
	func testSerializeSingleResourceWithoutToManyRelationships() {
		let options = SerializationOptions(includeToMany: false)
		let serializedData = serializer.serializeResources([foo], options: options)
		let json = JSON(data: serializedData)
		
		XCTAssertNotNil(json["data"]["links"]["toManyAttribute"].error, "Expected serialized to-many to be absent.")
	}
}

class DeserializingTests: SerializerTests {
	
	func testDeserializeSingleResource() {
		let fixture = JSONFixtureWithName("SingleFoo")
		let json = fixture.json
		let deserialisationResult = serializer.deserializeData(fixture.data, mappingTargets: nil)
		
		switch deserialisationResult {
		case .Success(let document):
			
			XCTAssertNotNil(document.data, "Expected data to be not nil.")
			
			if let resources = document.data {
				XCTAssertEqual(resources.count, 1, "Expected resources count to be 1.")
				
				XCTAssert(resources.first is Foo, "Expected resource to be of class 'Foo'.")
				let foo = resources.first as Foo
				
				// Attributes
				assertFooResource(foo, isEqualToJSON: json["data"])
				
				// To one link
				XCTAssertNotNil(foo.toOneAttribute, "Expected linked resource to be not nil.")
				if let bar = foo.toOneAttribute {
					
					XCTAssertNotNil(bar.URL, "Expected URL to not be nil")
					if let URL = bar.URL {
						XCTAssertEqual(URL, NSURL(string: json["data"]["links"]["toOneAttribute"]["related"].stringValue)!, "Deserialized link URL is not equal.")
					}
					
					XCTAssertFalse(bar.isLoaded, "Expected isLoaded to be false.")
				}
				
				// To many link
				XCTAssertNotNil(foo.toManyAttribute, "Deserialized linked resources should not be nil.")
				if let barCollection = foo.toManyAttribute {
					
					XCTAssertNotNil(barCollection.URL, "Expected URL to not be nil")
					if let URL = barCollection.URL {
						XCTAssertEqual(URL, NSURL(string: json["data"]["links"]["toManyAttribute"]["self"].stringValue)!, "Deserialized link URL is not equal.")
					}
					
					XCTAssertNotNil(barCollection.resourcesURL, "Expected resourcesURL to not be nil")
					if let resourcesURL = barCollection.resourcesURL {
						XCTAssertEqual(resourcesURL, NSURL(string: json["data"]["links"]["toManyAttribute"]["related"].stringValue)!, "Deserialized resource URL is not equal.")
					}
					
					XCTAssertFalse(barCollection.isLoaded, "Expected isLoaded to be false.")
				}
			}
			
		case .Failure(let error):
			XCTFail("Deserialisation failed with error: \(error).")
		}
	}
	
	func testDeserializeMultipleResources() {
		let fixture = JSONFixtureWithName("MultipleFoos")
		let deserialisationResult = serializer.deserializeData(fixture.data, mappingTargets: nil)

		switch deserialisationResult {
		case .Success(let document):
			
			XCTAssertNotNil(document.data, "Expected data to be not nil.")
			if let resources = document.data {
				XCTAssertEqual(resources.count, 2, "Expected resources count to be 2.")
				
				for (index, resource) in enumerate(resources) {
					let resourceJSON = fixture.json["data"][index]
					
					XCTAssert(resource is Foo, "Expected resource to be of class 'Foo'.")
					let foo = resource as Foo
					
					// Attributes
					assertFooResource(foo, isEqualToJSON: resourceJSON)
					
					// To one link
					XCTAssertNotNil(foo.toOneAttribute, "Expected linked resource to be not nil.")
					let bar = foo.toOneAttribute!
					XCTAssertEqual(bar.URL!.absoluteString!, resourceJSON["links"]["toOneAttribute"]["related"].stringValue, "Deserialized link URL is not equal.")
					XCTAssertFalse(bar.isLoaded, "Expected isLoaded to be false.")
					
					// To many link
					XCTAssertNotNil(foo.toManyAttribute, "Deserialized linked resources should not be nil.")
					let barCollection = foo.toManyAttribute!
					XCTAssertEqual(barCollection.URL!.absoluteString!, resourceJSON["links"]["toManyAttribute"]["self"].stringValue, "Deserialized link URL is not equal.")
					XCTAssertEqual(barCollection.resourcesURL!.absoluteString!, resourceJSON["links"]["toManyAttribute"]["related"].stringValue, "Deserialized resource URL is not equal.")
					XCTAssertFalse(barCollection.isLoaded, "Expected isLoaded to be false.")
				}
			}
			
		case .Failure(let error):
			XCTFail("Deserialisation failed with error: \(error).")
		}
	}
	
	func testDeserializeCompoundDocument() {
		let fixture = JSONFixtureWithName("SingleFooIncludingBars")
		let json = fixture.json
		let deserialisationResult = serializer.deserializeData(fixture.data, mappingTargets: nil)
		
		switch deserialisationResult {
		case .Success(let document):
			
			XCTAssertNotNil(document.data, "Expected data to be not nil.")
			if let resources = document.data {
				XCTAssertEqual(resources.count, 1, "Deserialized resources count not equal.")
				XCTAssert(resources.first is Foo, "Deserialized resource should be of class 'Foo'.")
				let foo = resources.first as Foo
				
				// Attributes
				assertFooResource(foo, isEqualToJSON: json["data"])
				
				// To one link
				XCTAssertNotNil(foo.toOneAttribute, "Deserialized linked resource should not be nil.")
				if let bar = foo.toOneAttribute {
					
					XCTAssertNotNil(bar.URL, "Expected URL to not be nil.")
					if let URL = bar.URL {
						XCTAssertEqual(URL, NSURL(string: json["data"]["links"]["toOneAttribute"]["related"].stringValue)!, "Deserialized link URL is not equal.")
					}
					
					XCTAssertNotNil(bar.id, "Expected id to not be nil.")
					if let id = bar.id {
						XCTAssertEqual(id, json["data"]["links"]["toOneAttribute"]["linkage"]["id"].stringValue, "Deserialized link id is not equal.")
					}
					
					XCTAssertTrue(bar.isLoaded, "Expected isLoaded is be true.")
				}
				
				// To many link
				XCTAssertNotNil(foo.toManyAttribute, "Deserialized linked resources should not be nil.")
				if let barCollection = foo.toManyAttribute {
					
					XCTAssertNotNil(barCollection.URL, "Expected URL to not be nil.")
					if let URL = barCollection.URL {
						XCTAssertEqual(URL, NSURL(string: json["data"]["links"]["toManyAttribute"]["self"].stringValue)!, "Deserialized link URL is not equal.")
					}
					
					XCTAssertNotNil(barCollection.resourcesURL, "Expected resourcesURL to not be nil.")
					if let URLString = barCollection.resourcesURL?.absoluteString {
						XCTAssertEqual(URLString, json["data"]["links"]["toManyAttribute"]["related"].stringValue, "Deserialized resource URL is not equal.")
					}
					
					XCTAssertTrue(barCollection.isLoaded, "Expected isLoaded to be true.")
					XCTAssertEqual(barCollection.linkage![0].type, "bars", "Expected first linkage item to be of type 'bars'.")
					XCTAssertEqual(barCollection.linkage![0].id, "11", "Expected first linkage item to have id '11'.")
					XCTAssertEqual(barCollection.linkage![1].type, "bars", "Expected second linkage item to be of type 'bars'.")
					XCTAssertEqual(barCollection.linkage![1].id, "12", "Expected second linkage item to have id '12'.")
				}
			}
			
		case .Failure(let error):
			XCTFail("Deserialisation failed with error: \(error).")
		}
	}
	
	func testDeserializeInvalidDocument() {
		let data = NSData()
		let deserialisationResult = serializer.deserializeData(data, mappingTargets: nil)
		
		switch deserialisationResult {
		case .Success(let document):
			XCTFail("Expected deserialization to fail.")
		case .Failure(let error):
			XCTAssertEqual(error.domain, SpineClientErrorDomain, "Expected error domain to be SpineClientErrorDomain.")
			XCTAssertEqual(error.code, SpineErrorCodes.InvalidDocumentStructure, "Expected error code to be 'InvalidDocumentStructure'.")
		}
	}
	
	func testDeserializeErrorsDocument() {
		let fixture = JSONFixtureWithName("Errors")
		let deserialisationResult = serializer.deserializeData(fixture.data, mappingTargets: nil)
		
		switch deserialisationResult {
		case .Success(let document):
			
			XCTAssertNotNil(document.errors, "Expected data to be not nil.")
			
			if let errors = document.errors {
				XCTAssertEqual(errors.count, 2, "Deserialized errors count not equal.")
				
				for (index, error) in enumerate(errors) {
					let errorJSON = fixture.json["errors"][index]
					XCTAssertEqual(error.domain, SpineServerErrorDomain, "Expected error domain to be SpineServerErrorDomain.")
					XCTAssertEqual(error.code, errorJSON["code"].intValue, "Expected error code to be equal.")
					XCTAssertEqual(error.localizedDescription, errorJSON["title"].stringValue, "Expected error description to be equal.")
				}
			}
			
		case .Failure(let error):
			XCTFail("Deserialisation failed with error: \(error).")
		}
	}
}