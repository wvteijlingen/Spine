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
		
		let expectation = expectationWithDescription("testFindByIDAndType")
		
		spine.find(["1","2"], ofType: Foo.self).onSuccess { fooCollection in
			expectation.fulfill()
			for (index, resource) in enumerate(fooCollection) {
				XCTAssertEqual(fooCollection.count, 2, "Deserialized resources count not equal.")
				XCTAssert(resource is Foo, "Deserialized resource should be of class 'Foo'.")
				let foo = resource as Foo
				compareAttributesOfFooResource(foo, withJSON: json["data"][index])
			}
		}.onFailure { error in
			expectation.fulfill()
			XCTFail("Find failed with error: \(error).")
		}
		
		waitForExpectationsWithTimeout(10) { error in
			XCTAssertNil(error, "\(error)")
		}
	}

//	func testFindByIDAndTypeWithAPIError() {
//		let path = testBundle.URLForResource("MultipleFoos", withExtension: "json")!
//		let data = NSData(contentsOfURL: path)!
//		let json = JSON(data: data)
//		
//		HTTPClient.handler = { (request: NSURLRequest, rawPayload: [String : AnyObject]?) -> (responseData: NSData, statusCode: Int, error: NSError?) in
//			return (responseData:data, statusCode: 404, error: nil)
//		}
//		
//		var failure = false
//		
//		spine.find(["1","2"], ofType: Foo.self).onSuccess { fooCollection in
//			XCTFail("Expected success callback to not be called.")
//		}.onFailure { error in
//			failure = true
//		}
//		
//		XCTAssertTrue(failure, "Expected failure callback to be called")
//	}
//	
//	func testFindByIDAndTypeWithNetworkError() {
//		HTTPClient.handler = { (request: NSURLRequest, rawPayload: [String : AnyObject]?) -> (responseData: NSData, statusCode: Int, error: NSError?) in
//			let networkError = NSError()
//			return (responseData: NSData(), statusCode: 404, error: networkError)
//		}
//		
//		var failure = false
//		
//		spine.find(["1","2"], ofType: Foo.self).onSuccess { fooCollection in
//			XCTFail("Expected success callback to not be called.")
//		}.onFailure { error in
//			failure = true
//			
//			
//		}
//		
//		XCTAssertTrue(failure, "Expected failure callback to be called")
//	}
	
	func testFindByType() {
		let path = testBundle.URLForResource("MultipleFoos", withExtension: "json")!
		let data = NSData(contentsOfURL: path)!
		let json = JSON(data: data)
		
		HTTPClient.handler = { (request: NSURLRequest, rawPayload: [String : AnyObject]?) -> (responseData: NSData, statusCode: Int, error: NSError?) in
			XCTAssertEqual(request.URL, NSURL(string:"http://example.com/foos/")!, "Request URL not as expected.")
			return (responseData: data, statusCode: 200, error: nil)
		}
		
		let expectation = expectationWithDescription("testFindByType")
		
		spine.find(Foo.self).onSuccess { fooCollection in
			expectation.fulfill()
			for (index, resource) in enumerate(fooCollection) {
				XCTAssertEqual(fooCollection.count, 2, "Deserialized resources count not equal.")
				XCTAssert(resource is Foo, "Deserialized resource should be of class 'Foo'.")
				let foo = resource as Foo
				compareAttributesOfFooResource(foo, withJSON: json["data"][index])
			}
		}.onFailure { error in
			expectation.fulfill()
			XCTFail("Find failed with error: \(error).")
		}
		
		waitForExpectationsWithTimeout(10) { error in
			XCTAssertNil(error, "\(error)")
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
		
		let expectation = expectationWithDescription("testFindOneByIDAndType")
		
		spine.findOne("1", ofType: Foo.self).onSuccess { foo in
			expectation.fulfill()
			compareAttributesOfFooResource(foo, withJSON: json["data"])
		}.onFailure { error in
			expectation.fulfill()
			XCTFail("Find failed with error: \(error).")
		}
		
		waitForExpectationsWithTimeout(10) { error in
			XCTAssertNil(error, "\(error)")
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
		let expectation = expectationWithDescription("testFindOneByQuery")
		
		spine.findOne(query).onSuccess { foo in
			expectation.fulfill()
			compareAttributesOfFooResource(foo, withJSON: json["data"])
		}.onFailure { error in
			expectation.fulfill()
			XCTFail("Find failed with error: \(error).")
		}
		
		waitForExpectationsWithTimeout(10) { error in
			XCTAssertNil(error, "\(error)")
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
		let expectation = expectationWithDescription("testFindByQuery")
		
		spine.find(query).onSuccess { fooCollection in
			expectation.fulfill()
			for (index, resource) in enumerate(fooCollection) {
				XCTAssertEqual(fooCollection.count, 2, "Deserialized resources count not equal.")
				XCTAssert(resource is Foo, "Deserialized resource should be of class 'Foo'.")
				let foo = resource as Foo
				compareAttributesOfFooResource(foo, withJSON: json["data"][index])
			}
		}.onFailure { error in
			expectation.fulfill()
			XCTFail("Find failed with error: \(error).")
		}
		
		waitForExpectationsWithTimeout(10) { error in
			XCTAssertNil(error, "\(error)")
		}
	}
}
