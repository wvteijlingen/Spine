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
	let serializer = Serializer()
	
	override func setUp() {
		super.setUp()
		serializer.keyFormatter = DasherizedKeyFormatter()
		serializer.registerResource(Foo.self)
		serializer.registerResource(Bar.self)
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
		foo.dateAttribute = Date(timeIntervalSince1970: 0)
		foo.toOneAttribute = Bar(id: "10")
		foo.toManyAttribute = LinkedResourceCollection(resourcesURL: nil, linkURL: nil, linkage: nil)
		foo.toManyAttribute?.appendResource(Bar(id: "11"))
		foo.toManyAttribute?.appendResource(Bar(id: "12"))
	}
	
	func serializedJSONWithOptions(_ options: SerializationOptions) -> JSON {
		let serializedData = try! serializer.serializeResources([foo], options: options)
		return JSON(data: serializedData)
	}
	
	func testSerializeSingleResourceAttributes() {
		let json = serializedJSONWithOptions([.IncludeID])
		
		XCTAssertEqual(json["data"]["id"].stringValue, foo.id!, "Serialized id is not equal.")
		XCTAssertEqual(json["data"]["type"].stringValue, foo.resourceType, "Serialized type is not equal.")
		XCTAssertEqual(json["data"]["attributes"]["integer-attribute"].intValue, foo.integerAttribute?.intValue, "Serialized integer is not equal.")
		XCTAssertEqual(json["data"]["attributes"]["float-attribute"].floatValue, foo.floatAttribute?.floatValue, "Serialized float is not equal.")
		XCTAssertTrue(json["data"]["attributes"]["boolean-attribute"].boolValue, "Serialized boolean is not equal.")
		XCTAssertNotNil(json["data"]["attributes"]["nil-attribute"].null, "Serialized nil is not equal.")
		XCTAssertEqual(json["data"]["attributes"]["date-attribute"].stringValue, ISO8601FormattedDate(foo.dateAttribute!), "Serialized date is not equal.")
	}
	
	func testSerializeSingleResourceToOneRelationships() {
		let json = serializedJSONWithOptions([.IncludeID, .IncludeToOne])
		
		XCTAssertEqual(json["data"]["relationships"]["to-one-attribute"]["data"]["id"].stringValue, foo.toOneAttribute!.id!, "Serialized to-one id is not equal")
		XCTAssertEqual(json["data"]["relationships"]["to-one-attribute"]["data"]["type"].stringValue, Bar.resourceType, "Serialized to-one type is not equal")
	}
	
	func testSerializeSingleResourceToManyRelationships() {
		let json = serializedJSONWithOptions([.IncludeID, .IncludeToOne, .IncludeToMany])
		
		XCTAssertEqual(json["data"]["relationships"]["to-many-attribute"]["data"][0]["id"].stringValue, "11", "Serialized to-many id is not equal")
		XCTAssertEqual(json["data"]["relationships"]["to-many-attribute"]["data"][0]["type"].stringValue, Bar.resourceType, "Serialized to-many type is not equal")
		
		XCTAssertEqual(json["data"]["relationships"]["to-many-attribute"]["data"][1]["id"].stringValue, "12", "Serialized to-many id is not equal")
		XCTAssertEqual(json["data"]["relationships"]["to-many-attribute"]["data"][1]["type"].stringValue, Bar.resourceType, "Serialized to-many type is not equal")
	}
	
	func testSerializeSingleResourceWithoutID() {
		let json = serializedJSONWithOptions([.IncludeToOne, .IncludeToMany])
		
		XCTAssertNotNil(json["data"]["id"].error, "Expected serialized id to be absent.")
	}
	
	func testSerializeSingleResourceWithoutToOneRelationships() {
		let json = serializedJSONWithOptions([.IncludeID, .IncludeToMany])

		XCTAssertNotNil(json["data"]["relationships"]["to-one-attribute"].error, "Expected serialized to-one to be absent")
	}
	
	func testSerializeSingleResourceWithoutToManyRelationships() {
		let options:SerializationOptions = [.IncludeID, .IncludeToOne]
		let serializedData = try! serializer.serializeResources([foo], options: options)
		let json = JSON(data: serializedData)
		
		XCTAssertNotNil(json["data"]["relationships"]["to-many-attribute"].error, "Expected serialized to-many to be absent.")
	}
    
    func testSerializeResourceOmittingNulls() {
        let options: SerializationOptions = [.OmitNullValues]
        let serializedData = try! serializer.serializeResources([foo], options: options)
        let json = JSON(data: serializedData)
        XCTAssertNotNil(json["data"]["attributes"]["nil-attribute"].error, "Expected serialized nil to be absent.")
    }
}

class DeserializingTests: SerializerTests {
	
	func testDeserializeSingleResource() {
		let fixture = JSONFixtureWithName("SingleFoo")
		let json = fixture.json
		
		do {
			let document = try serializer.deserializeData(fixture.data)
			XCTAssertNotNil(document.data, "Expected data to be not nil.")
			
			if let resources = document.data {
				XCTAssertEqual(resources.count, 1, "Expected resources count to be 1.")
				
				XCTAssert(resources.first is Foo, "Expected resource to be of class 'Foo'.")
				let foo = resources.first as! Foo
				
				// Attributes
				assertFooResource(foo, isEqualToJSON: json["data"])
				
				// To one link
				XCTAssertNotNil(foo.toOneAttribute, "Expected linked resource to be not nil.")
				if let bar = foo.toOneAttribute {
					
					XCTAssertNotNil(bar.url, "Expected URL to not be nil")
					if let url = bar.url {
						XCTAssertEqual(url, URL(string: json["data"]["relationships"]["to-one-attribute"]["links"]["related"].stringValue)!, "Deserialized link URL is not equal.")
					}
					
					XCTAssertFalse(bar.isLoaded, "Expected isLoaded to be false.")
				}
				
				// To many link
				XCTAssertNotNil(foo.toManyAttribute, "Deserialized linked resources should not be nil.")
				if let barCollection = foo.toManyAttribute {
					
					XCTAssertNotNil(barCollection.linkURL, "Expected link URL to not be nil")
					if let url = barCollection.linkURL {
						XCTAssertEqual(url, URL(string: json["data"]["relationships"]["to-many-attribute"]["links"]["self"].stringValue)!, "Deserialized link URL is not equal.")
					}
					
					XCTAssertNotNil(barCollection.resourcesURL, "Expected resourcesURL to not be nil")
					if let resourcesURL = barCollection.resourcesURL {
						XCTAssertEqual(resourcesURL, URL(string: json["data"]["relationships"]["to-many-attribute"]["links"]["related"].stringValue)!, "Deserialized resource URL is not equal.")
					}
					
					XCTAssertFalse(barCollection.isLoaded, "Expected isLoaded to be false.")
				}
			}
		} catch let error as NSError {
			XCTFail("Deserialisation failed with error: \(error).")
		}
	}
	
	func testDeserializeSingleResourceWithUnregisteredType() {
		let fixture = JSONFixtureWithName("SingleFooWithUnregisteredType")
		
		do {
			let document = try serializer.deserializeData(fixture.data)
			XCTAssertNotNil(document.data, "Expected data to be not nil.")
			
			if let resources = document.data {
				XCTAssertEqual(resources.count, 1, "Expected resources count to be 1.")
				
				XCTAssert(resources.first is Foo, "Expected resource to be of class 'Foo'.")
				let foo = resources.first as! Foo
				
				// To one link
				XCTAssertNotNil(foo.toOneAttribute, "Expected linked resource to be not nil.")
				
				// To many link
				XCTAssertNotNil(foo.toManyAttribute, "Deserialized linked resources should not be nil.")
				if let barCollection = foo.toManyAttribute {
					for bar in barCollection {
						XCTAssert(bar is Bar, "Expected relationship resource to be of class 'Bar'.")
					}
				}
			}
		} catch let error as NSError {
			XCTFail("Deserialisation failed with error: \(error).")
		}
	}
	
	func testDeserializeMultipleResources() {
		let fixture = JSONFixtureWithName("MultipleFoos")
		
		do {
			let document = try serializer.deserializeData(fixture.data, mappingTargets: nil)
			
			XCTAssertNotNil(document.data, "Expected data to be not nil.")
			if let resources = document.data {
				XCTAssertEqual(resources.count, 2, "Expected resources count to be 2.")
				
				for (index, resource) in resources.enumerated() {
					let resourceJSON = fixture.json["data"][index]
					
					XCTAssert(resource is Foo, "Expected resource to be of class 'Foo'.")
					let foo = resource as! Foo
					
					// Attributes
					assertFooResource(foo, isEqualToJSON: resourceJSON)
					
					// To one link
					XCTAssertNotNil(foo.toOneAttribute, "Expected linked resource to be not nil.")
					let bar = foo.toOneAttribute!
					XCTAssertEqual(bar.url!.absoluteString, resourceJSON["relationships"]["to-one-attribute"]["links"]["related"].stringValue, "Deserialized resource URL is not equal.")
					XCTAssertFalse(bar.isLoaded, "Expected isLoaded to be false.")
					
					// To many link
					if let barCollection = foo.toManyAttribute {
						XCTAssertEqual(barCollection.linkURL!.absoluteString, resourceJSON["relationships"]["to-many-attribute"]["links"]["self"].stringValue, "Deserialized link URL is not equal.")
						XCTAssertEqual(barCollection.resourcesURL!.absoluteString, resourceJSON["relationships"]["to-many-attribute"]["links"]["related"].stringValue, "Deserialized resource URL is not equal.")
						XCTAssertFalse(barCollection.isLoaded, "Expected isLoaded to be false.")
					} else {
						XCTFail("Deserialized linked resources should not be nil")
					}
				}
			}

		} catch let error as NSError {
			XCTFail("Deserialisation failed with error: \(error).")
		}
	}

  func testDeserializeEmptyResources() {
    let fixture = JSONFixtureWithName("EmptyFoos")

    do {
      let document = try serializer.deserializeData(fixture.data, mappingTargets: nil)

      guard let foos = document.data else {
        XCTFail("Expected data to be not nil.")
        return
      }

      XCTAssert(foos.isEmpty, "Expected an empty array.")

    } catch let error as NSError {
      XCTFail("Deserialisation failed with error: \(error).")
    }
  }
	
	func testDeserializeCompoundDocument() {
		let fixture = JSONFixtureWithName("SingleFooIncludingBars")
		let json = fixture.json
		
		do {
			let document = try serializer.deserializeData(fixture.data)
			
			XCTAssertNotNil(document.data, "Expected data to be not nil.")
			if let resources = document.data {
				XCTAssertEqual(resources.count, 1, "Deserialized resources count not equal.")
				XCTAssert(resources.first is Foo, "Deserialized resource should be of class 'Foo'.")
				let foo = resources.first as! Foo
				
				// Attributes
				assertFooResource(foo, isEqualToJSON: json["data"])
				
				// To one link
				XCTAssertNotNil(foo.toOneAttribute, "Deserialized linked resource should not be nil.")
				if let bar = foo.toOneAttribute {
					
					XCTAssertNotNil(bar.url, "Expected URL to not be nil.")
					if let url = bar.url {
						XCTAssertEqual(url, URL(string: json["data"]["relationships"]["to-one-attribute"]["links"]["related"].stringValue)!, "Deserialized resource URL is not equal.")
					}
					
					XCTAssertNotNil(bar.id, "Expected id to not be nil.")
					if let id = bar.id {
						XCTAssertEqual(id, json["data"]["relationships"]["to-one-attribute"]["data"]["id"].stringValue, "Deserialized link id is not equal.")
					}
					
					XCTAssertTrue(bar.isLoaded, "Expected isLoaded is be true.")
				}
				
				// To many link
				XCTAssertNotNil(foo.toManyAttribute, "Deserialized linked resources should not be nil.")
				if let barCollection = foo.toManyAttribute {
					
					XCTAssertNotNil(barCollection.linkURL, "Expected link URL to not be nil.")
					if let URL = barCollection.linkURL {
						XCTAssertEqual(URL, Foundation.URL(string: json["data"]["relationships"]["to-many-attribute"]["links"]["self"].stringValue)!, "Deserialized link URL is not equal.")
					}
					
					XCTAssertNotNil(barCollection.resourcesURL, "Expected resourcesURL to not be nil.")
					if let URLString = barCollection.resourcesURL?.absoluteString {
						XCTAssertEqual(URLString, json["data"]["relationships"]["to-many-attribute"]["links"]["related"].stringValue, "Deserialized resource URL is not equal.")
					}
					
					XCTAssertTrue(barCollection.isLoaded, "Expected isLoaded to be true.")
					XCTAssertEqual(barCollection.linkage![0].type, "bars", "Expected first linkage item to be of type 'bars'.")
					XCTAssertEqual(barCollection.linkage![0].id, "11", "Expected first linkage item to have id '11'.")
					XCTAssertEqual(barCollection.linkage![1].type, "bars", "Expected second linkage item to be of type 'bars'.")
					XCTAssertEqual(barCollection.linkage![1].id, "12", "Expected second linkage item to have id '12'.")
				}
			}
			
			
		} catch let error as NSError {
			XCTFail("Deserialisation failed with error: \(error).")
		}
	}
	
	func testDeserializeWithInvalidDocumentStructure() {
		let data = Data()
		
		do {
			try _ = serializer.deserializeData(data)
			XCTFail("Expected deserialization to fail.")
		} catch SerializerError.invalidDocumentStructure {
			// All is well
		} catch {
			XCTFail("Expected error domain to be SerializerError.InvalidDocumentStructure.")
		}
	}
	
	func testDeserializeWithoutTopLevelEntry() {
		let data = try! JSONSerialization.data(withJSONObject: [:], options: [])
		
		do {
			try _ = serializer.deserializeData(data)
			XCTFail("Expected deserialization to fail.")
		} catch SerializerError.topLevelEntryMissing {
			// All is well
		} catch {
			XCTFail("Expected error domain to be SerializerError.TopLevelEntryMissing.")
		}
	}
	
	func testDeserializeWithCoexistingDataAndErrors() {
		let data = try! JSONSerialization.data(withJSONObject: ["data": [], "errors": []], options: [])
		
		do {
			try _ = serializer.deserializeData(data)
			XCTFail("Expected deserialization to fail.")
		} catch SerializerError.topLevelDataAndErrorsCoexist {
			// All is well
		} catch {
			XCTFail("Expected error domain to be SerializerError.TopLevelDataAndErrorsCoexist.")
		}
	}
	
	func testDeserializeWithNullData() {
		let data = try! JSONSerialization.data(withJSONObject: ["data": NSNull()], options: [])
		
		do {
			try _ = serializer.deserializeData(data)
		} catch {
			XCTFail("Expected deserialization to succeed.")
		}
	}
	
	func testDeserializeErrorsDocument() {
		let fixture = JSONFixtureWithName("Errors")
		
		do {
			let document = try serializer.deserializeData(fixture.data)
			
			XCTAssertNotNil(document.errors, "Expected data to be not nil.")
			
			if let errors = document.errors {
				XCTAssertEqual(errors.count, 2, "Deserialized errors count not equal.")
				
				for (index, error) in errors.enumerated() {
					let errorJSON = fixture.json["errors"][index]
					XCTAssertEqual(error.id, errorJSON["id"].stringValue)
					XCTAssertEqual(error.status, errorJSON["status"].stringValue)
					XCTAssertEqual(error.code, errorJSON["code"].stringValue)
					XCTAssertEqual(error.title, errorJSON["title"].stringValue)
					XCTAssertEqual(error.detail, errorJSON["detail"].stringValue)
				}
			}
			
		} catch let error {
			XCTFail("Deserialisation failed with error: \(error).")
		}
	}
}
