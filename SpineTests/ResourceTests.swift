//
//  ResourceTests.swift
//  Spine
//
//  Created by Ward van Teijlingen on 06-03-15.
//  Copyright (c) 2015 Ward van Teijlingen. All rights reserved.
//

import XCTest

class ResourceTests: XCTestCase {
	
	let foo: Foo = Foo(id: "1")
	
	override func setUp() {
		super.setUp()
		foo.stringAttribute = "stringAttribute"
		foo.nilAttribute = nil
		foo.toOneAttribute = Bar(id: "10")
	}

	func testGetAttributeValue() {
		let value = foo.value(forField: "stringAttribute")
		
		XCTAssertNotNil(value, "Expected value to be not nil")
		
		if let value = value as? String {
			XCTAssertEqual(value, foo.stringAttribute!, "Expected value to be equal")
		} else {
			XCTFail("Expected value to be of type 'String'")
		}
	}
	
	func testGetNilAttributeValue() {
		let value = foo.value(forField: "nilAttribute")
		
		XCTAssertNil(value, "Expected value to be nil")
	}
	
	func testGetRelationshipValue() {
		let value = foo.value(forField: "toOneAttribute")
		
		XCTAssertNotNil(value, "Expected value to be not nil")
		
		if let value = value as? Bar {
			XCTAssertEqual(value, foo.toOneAttribute!, "Expected value to be equal")
		} else {
			XCTFail("Expected value to be of type 'Bar'")
		}
	}
	
	func testSetAttributeValue() {
		foo.setValue("newStringValue", forField: "stringAttribute")
		
	}
	
	func testEncoding() {
		foo.url = URL(string: "http://example.com/api/foos/1")
		foo.isLoaded = true
		
		let encodedData = NSKeyedArchiver.archivedData(withRootObject: foo)
		let decodedFoo: AnyObject? = NSKeyedUnarchiver.unarchiveObject(with: encodedData) as AnyObject?
		
		XCTAssertNotNil(decodedFoo, "Expected decoded object to be not nil")
		XCTAssert(decodedFoo is Foo, "Expected decoded object to be of type 'Foo'")
		
		if let decodedFoo = decodedFoo as? Foo {
			XCTAssertEqual(decodedFoo.id!, foo.id!, "Expected id to be equal")
			XCTAssertEqual(decodedFoo.url!, foo.url!, "Expected URL to be equal")
			XCTAssertEqual(decodedFoo.isLoaded, foo.isLoaded, "Expected isLoaded to be equal")
		} else {
			XCTFail("Fail")
		}
	}
}
