//
//  SpineTests.swift
//  SpineTests
//
//  Created by Ward van Teijlingen on 30-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import UIKit
import XCTest
import SwiftyJSON

class SpineTests: XCTestCase {
	var spine: Spine!
	var HTTPClient: CallbackHTTPClient!
	
    override func setUp() {
        super.setUp()
		spine = Spine(baseURL: NSURL(string:"http://example.com")!)
		HTTPClient = CallbackHTTPClient()
		spine.HTTPClient = HTTPClient
		spine.registerResource(Foo.resourceType) { Foo() }
		spine.registerResource(Bar.resourceType) { Bar() }
    }
    
    override func tearDown() {
        super.tearDown()
    }
	
	func testFindByIDAndType() {
		let path = testBundle.URLForResource("MultipleFoos", withExtension: "json")!
		let data = NSData(contentsOfURL: path)!
		let json = JSON(data: data)
		
		HTTPClient.handler = { (request: NSURLRequest, rawPayload: [String : AnyObject]?) -> (responseData: NSData, statusCode: Int, error: NSError?) in
			XCTAssertEqual(request.URL, NSURL(string:"http://example.com/foos/?filter[id]=1,2")!, "Request URL not as expected.")
			return (responseData: data, statusCode: 200, error: nil)
		}
		
		spine.find(["1","2"], ofType: Foo.self).onSuccess { fooCollection in
			for (index, resource) in enumerate(fooCollection) {
				XCTAssertEqual(fooCollection.count, 2, "Deserialized resources count not equal.")
				XCTAssert(resource is Foo, "Deserialized resource should be of class 'Foo'.")
				let foo = resource as Foo
				self.compareAttributesOfFooResource(foo, withJSON: json["data"][index])
			}
		}
	}
	
	func testFindByType() {
		let path = testBundle.URLForResource("MultipleFoos", withExtension: "json")!
		let data = NSData(contentsOfURL: path)!
		let json = JSON(data: data)
		
		HTTPClient.handler = { (request: NSURLRequest, rawPayload: [String : AnyObject]?) -> (responseData: NSData, statusCode: Int, error: NSError?) in
			XCTAssertEqual(request.URL, NSURL(string:"http://example.com/foos/")!, "Request URL not as expected.")
			return (responseData: data, statusCode: 200, error: nil)
		}
		
		spine.find(Foo.self).onSuccess { fooCollection in
			for (index, resource) in enumerate(fooCollection) {
				XCTAssertEqual(fooCollection.count, 2, "Deserialized resources count not equal.")
				XCTAssert(resource is Foo, "Deserialized resource should be of class 'Foo'.")
				let foo = resource as Foo
				self.compareAttributesOfFooResource(foo, withJSON: json["data"][index])
			}
		}
	}
    
    func testFindOneByIDAndType() {
		let path = testBundle.URLForResource("SingleFoo", withExtension: "json")!
		let data = NSData(contentsOfURL: path)!
		let json = JSON(data: data)
		
		HTTPClient.handler = { (request: NSURLRequest, rawPayload: [String : AnyObject]?) -> (responseData: NSData, statusCode: Int, error: NSError?) in
			XCTAssertEqual(request.URL, NSURL(string:"http://example.com/foos/1")!, "Request URL not as expected.")
			return (responseData: data, statusCode: 200, error: nil)
		}
		
		spine.findOne("1", ofType: Foo.self).onSuccess { foo in
			self.compareAttributesOfFooResource(foo, withJSON: json["data"])
		}
    }

	
	func testFindOneByQuery() {
		let path = testBundle.URLForResource("SingleFoo", withExtension: "json")!
		let data = NSData(contentsOfURL: path)!
		let json = JSON(data: data)
		
		HTTPClient.handler = { (request: NSURLRequest, rawPayload: [String : AnyObject]?) -> (responseData: NSData, statusCode: Int, error: NSError?) in
			XCTAssertEqual(request.URL, NSURL(string:"http://example.com/foos/1")!, "Request URL not as expected.")
			return (responseData: data, statusCode: 200, error: nil)
		}
		
		let query = Query(resourceType: Foo.self, resourceIDs: ["1"])
		
		spine.findOne(query).onSuccess { foo in
			self.compareAttributesOfFooResource(foo, withJSON: json["data"])
		}
	}
	
	func testFindByQuery() {
		let path = testBundle.URLForResource("MultipleFoos", withExtension: "json")!
		let data = NSData(contentsOfURL: path)!
		let json = JSON(data: data)
		
		HTTPClient.handler = { (request: NSURLRequest, rawPayload: [String : AnyObject]?) -> (responseData: NSData, statusCode: Int, error: NSError?) in
			XCTAssertEqual(request.URL, NSURL(string:"http://example.com/foos/?filter[id]=1,2")!, "Request URL not as expected.")
			return (responseData: data, statusCode: 200, error: nil)
		}
		
		let query = Query(resourceType: Foo.self, resourceIDs: ["1", "2"])
		
		spine.find(query).onSuccess { fooCollection in
			for (index, resource) in enumerate(fooCollection) {
				XCTAssertEqual(fooCollection.count, 2, "Deserialized resources count not equal.")
				XCTAssert(resource is Foo, "Deserialized resource should be of class 'Foo'.")
				let foo = resource as Foo
				self.compareAttributesOfFooResource(foo, withJSON: json["data"][index])
			}
		}
	}
	
	func compareAttributesOfFooResource(foo: Foo, withJSON json: JSON) {
		XCTAssertEqual(foo.stringAttribute!, json["stringAttribute"].stringValue, "Deserialized string attribute is not equal.")
		XCTAssertEqual(foo.integerAttribute!, json["integerAttribute"].intValue, "Deserialized integer attribute is not equal.")
		XCTAssertEqual(foo.floatAttribute!, json["floatAttribute"].floatValue, "Deserialized float attribute is not equal.")
		XCTAssertEqual(foo.booleanAttribute!, json["integerAttribute"].boolValue, "Deserialized boolean attribute is not equal.")
		XCTAssertNil(foo.nilAttribute, "Deserialized nil attribute is not equal.")
		XCTAssertEqual(foo.dateAttribute!, NSDate(timeIntervalSince1970: 0), "Deserialized date attribute is not equal.")
	}
	
}
