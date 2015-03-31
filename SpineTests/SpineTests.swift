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
import BrightFutures

class SpineTests: XCTestCase {
	var spine: Spine!
	var HTTPClient: CallbackHTTPClient!
	
	override func setUp() {
		super.setUp()
		spine = Spine(baseURL: NSURL(string:"http://example.com")!)
		HTTPClient = CallbackHTTPClient()
		spine._HTTPClient = HTTPClient
		spine.registerResource(Foo.resourceType) { Foo() }
		spine.registerResource(Bar.resourceType) { Bar() }
	}
}

// MARK: -

class FindTests: SpineTests {

	// MARK: Find by type
	
	func testFindByType() {
		let fixture = JSONFixtureWithName("MultipleFoos")
		
		HTTPClient.handler = { (request: NSURLRequest, payload: NSData?) -> (responseData: NSData, statusCode: Int, error: NSError?) in
			XCTAssertEqual(request.HTTPMethod!, "GET", "HTTP method not as expected.")
			XCTAssertEqual(request.URL, NSURL(string:"http://example.com/foos/")!, "Request URL not as expected.")
			return (responseData: fixture.data, statusCode: 200, error: nil)
		}
		
		let expectation = expectationWithDescription("testFindByType")
		
		spine.find(Foo.self).onSuccess { fooCollection in
			expectation.fulfill()
			for (index, resource) in enumerate(fooCollection) {
				XCTAssertEqual(fooCollection.count, 2, "Deserialized resources count not equal.")
				XCTAssert(resource is Foo, "Deserialized resource should be of class 'Foo'.")
				let foo = resource as Foo
				assertFooResource(foo, isEqualToJSON: fixture.json["data"][index])
			}
			}.onFailure { error in
				expectation.fulfill()
				XCTFail("Find failed with error: \(error).")
		}
		
		waitForExpectationsWithTimeout(10) { error in
			XCTAssertNil(error, "\(error)")
		}
	}
	
	func testFindByTypeWithAPIError() {
		HTTPClient.respondWith(404)
		
		let expectation = expectationWithDescription("testFindByTypeWithAPIError")
		let future = spine.find(Foo.self)
		assertFutureFailure(future, withErrorDomain: SPINE_API_ERROR_DOMAIN, errorCode: 404, expectation)
		
		waitForExpectationsWithTimeout(10) { error in
			XCTAssertNil(error, "\(error)")
		}
	}
	
	func testFindByTypeWithNetworkError() {
		HTTPClient.respondWith(404, error: NSError(domain: "mock", code: 999, userInfo: nil))
		
		let expectation = expectationWithDescription("testFindByTypeWithNetworkError")
		let future = spine.find(Foo.self)
		assertFutureFailure(future, withErrorDomain: SPINE_ERROR_DOMAIN, errorCode: 999, expectation)
		
		waitForExpectationsWithTimeout(10) { error in
			XCTAssertNil(error, "\(error)")
		}
	}
	
	
	// MARK: Find by ID and type
	
	func testFindByIDAndType() {
		let fixture = JSONFixtureWithName("MultipleFoos")
		
		HTTPClient.handler = { request, payload in
			XCTAssertEqual(request.HTTPMethod!, "GET", "HTTP method not as expected.")
			XCTAssertEqual(request.URL, NSURL(string:"http://example.com/foos/?filter[id]=1,2")!, "Request URL not as expected.")
			return (responseData: fixture.data, statusCode: 200, error: nil)
		}
		
		let expectation = expectationWithDescription("testFindByIDAndType")
		
		spine.find(["1","2"], ofType: Foo.self).onSuccess { fooCollection in
			expectation.fulfill()
			for (index, resource) in enumerate(fooCollection) {
				XCTAssertEqual(fooCollection.count, 2, "Expected resource count to be 2.")
				XCTAssert(resource is Foo, "Expected resource to be of class 'Foo'.")
				let foo = resource as Foo
				assertFooResource(foo, isEqualToJSON: fixture.json["data"][index])
			}
		}.onFailure { error in
			expectation.fulfill()
			XCTFail("Find failed with error: \(error).")
		}
		
		waitForExpectationsWithTimeout(10) { error in
			XCTAssertNil(error, "\(error)")
		}
	}
	
	func testFindByIDAndTypeWithAPIError() {
		HTTPClient.respondWith(404)
		
		let expectation = expectationWithDescription("testFindByIDAndTypeWithAPIError")
		let future = spine.find(["1","2"], ofType: Foo.self)
		assertFutureFailure(future, withErrorDomain: SPINE_API_ERROR_DOMAIN, errorCode: 404, expectation)
		
		waitForExpectationsWithTimeout(10) { error in
			XCTAssertNil(error, "\(error)")
		}
	}
	
	func testFindByIDAndTypeWithNetworkError() {
		let networkError = NSError(domain: "mock", code: 999, userInfo: nil)
		HTTPClient.respondWith(404, error: networkError)
		
		let expectation = expectationWithDescription("testFindByIDAndTypeWithNetworkError")
		let future = spine.find(["1","2"], ofType: Foo.self)
		assertFutureFailure(future, withErrorDomain: SPINE_ERROR_DOMAIN, errorCode: 999, expectation)
		
		waitForExpectationsWithTimeout(10) { error in
			XCTAssertNil(error, "\(error)")
		}
	}
	
	
	// MARK: Find one by ID and type
	
	func testFindOneByIDAndType() {
		let fixture = JSONFixtureWithName("SingleFoo")
		
		HTTPClient.handler = { (request: NSURLRequest, payload: NSData?) -> (responseData: NSData, statusCode: Int, error: NSError?) in
			XCTAssertEqual(request.HTTPMethod!, "GET", "HTTP method not as expected.")
			XCTAssertEqual(request.URL, NSURL(string:"http://example.com/foos/1")!, "Request URL not as expected.")
			return (responseData: fixture.data, statusCode: 200, error: nil)
		}
		
		let expectation = expectationWithDescription("testFindOneByIDAndType")
		
		spine.findOne("1", ofType: Foo.self).onSuccess { foo in
			expectation.fulfill()
			assertFooResource(foo, isEqualToJSON: fixture.json["data"])
			}.onFailure { error in
				expectation.fulfill()
				XCTFail("Find failed with error: \(error).")
		}
		
		waitForExpectationsWithTimeout(10) { error in
			XCTAssertNil(error, "\(error)")
		}
	}
	
	func testFindOneByTypeWithAPIError() {
		HTTPClient.respondWith(404)
		
		let expectation = expectationWithDescription("testFindOneByTypeWithAPIError")
		let future = spine.findOne("1", ofType: Foo.self)
		assertFutureFailure(future, withErrorDomain: SPINE_API_ERROR_DOMAIN, errorCode: 404, expectation)
		
		waitForExpectationsWithTimeout(10) { error in
			XCTAssertNil(error, "\(error)")
		}
	}
	
	func testFindOneByTypeWithNetworkError() {
		HTTPClient.respondWith(404, error: NSError(domain: "mock", code: 999, userInfo: nil))
		
		let expectation = expectationWithDescription("testFindOneByTypeWithNetworkError")
		let future = spine.findOne("1", ofType: Foo.self)
		assertFutureFailure(future, withErrorDomain: SPINE_ERROR_DOMAIN, errorCode: 999, expectation)
		
		waitForExpectationsWithTimeout(10) { error in
			XCTAssertNil(error, "\(error)")
		}
	}
	
	
	// MARK: Find by query
	
	func testFindByQuery() {
		let fixture = JSONFixtureWithName("MultipleFoos")
		
		HTTPClient.handler = { (request: NSURLRequest, payload: NSData?) -> (responseData: NSData, statusCode: Int, error: NSError?) in
			XCTAssertEqual(request.HTTPMethod!, "GET", "HTTP method not as expected.")
			XCTAssertEqual(request.URL, NSURL(string:"http://example.com/foos/?filter[id]=1,2")!, "Request URL not as expected.")
			return (responseData: fixture.data, statusCode: 200, error: nil)
		}
		
		let query = Query(resourceType: Foo.self, resourceIDs: ["1", "2"])
		let expectation = expectationWithDescription("testFindByQuery")
		
		spine.find(query).onSuccess { fooCollection in
			expectation.fulfill()
			for (index, resource) in enumerate(fooCollection) {
				XCTAssertEqual(fooCollection.count, 2, "Deserialized resources count not equal.")
				XCTAssert(resource is Foo, "Deserialized resource should be of class 'Foo'.")
				let foo = resource as Foo
				assertFooResource(foo, isEqualToJSON: fixture.json["data"][index])
			}
		}.onFailure { error in
			expectation.fulfill()
			XCTFail("Find failed with error: \(error).")
		}
		
		waitForExpectationsWithTimeout(10) { error in
			XCTAssertNil(error, "\(error)")
		}
	}
	
	func testFindByQueryWithAPIError() {
		HTTPClient.respondWith(404)
		
		let expectation = expectationWithDescription("testFindByQueryWithAPIError")
		
		let query = Query(resourceType: Foo.self, resourceIDs: ["1"])
		let future = spine.find(query)
		assertFutureFailure(future, withErrorDomain: SPINE_API_ERROR_DOMAIN, errorCode: 404, expectation)
		
		waitForExpectationsWithTimeout(10) { error in
			XCTAssertNil(error, "\(error)")
		}
	}
	
	func testFindByQueryWithNetworkError() {
		HTTPClient.respondWith(404, error: NSError(domain: "mock", code: 999, userInfo: nil))
		
		let expectation = expectationWithDescription("testFindByQueryWithNetworkError")
		
		let query = Query(resourceType: Foo.self, resourceIDs: ["1"])
		let future = spine.find(query)
		assertFutureFailure(future, withErrorDomain: SPINE_ERROR_DOMAIN, errorCode: 999, expectation)
		
		waitForExpectationsWithTimeout(10) { error in
			XCTAssertNil(error, "\(error)")
		}
	}
	
	
	// MARK: Find one by query
	
	func testFindOneByQuery() {
		let fixture = JSONFixtureWithName("SingleFoo")
		
		HTTPClient.handler = { (request: NSURLRequest, payload: NSData?) -> (responseData: NSData, statusCode: Int, error: NSError?) in
			XCTAssertEqual(request.HTTPMethod!, "GET", "HTTP method not as expected.")
			XCTAssertEqual(request.URL, NSURL(string:"http://example.com/foos/1")!, "Request URL not as expected.")
			return (responseData: fixture.data, statusCode: 200, error: nil)
		}
		
		let query = Query(resourceType: Foo.self, resourceIDs: ["1"])
		let expectation = expectationWithDescription("testFindOneByQuery")
		
		spine.findOne(query).onSuccess { foo in
			expectation.fulfill()
			assertFooResource(foo, isEqualToJSON: fixture.json["data"])
		}.onFailure { error in
			expectation.fulfill()
			XCTFail("Find failed with error: \(error).")
		}
		
		waitForExpectationsWithTimeout(10) { error in
			XCTAssertNil(error, "\(error)")
		}
	}
	
	func testFindOneByQueryWithAPIError() {
		HTTPClient.respondWith(404)
		
		let expectation = expectationWithDescription("testFindOneByQueryWithAPIError")
		
		let query = Query(resourceType: Foo.self, resourceIDs: ["1"])
		let future = spine.findOne(query)
		assertFutureFailure(future, withErrorDomain: SPINE_API_ERROR_DOMAIN, errorCode: 404, expectation)
		
		waitForExpectationsWithTimeout(10) { error in
			XCTAssertNil(error, "\(error)")
		}
	}
	
	func testFindOneByQueryWithNetworkError() {
		HTTPClient.respondWith(404, error: NSError(domain: "mock", code: 999, userInfo: nil))
		
		let expectation = expectationWithDescription("testFindOneByQueryWithNetworkError")
		
		let query = Query(resourceType: Foo.self, resourceIDs: ["1"])
		let future = spine.findOne(query)
		assertFutureFailure(future, withErrorDomain: SPINE_ERROR_DOMAIN, errorCode: 999, expectation)
		
		waitForExpectationsWithTimeout(10) { error in
			XCTAssertNil(error, "\(error)")
		}
	}
}

// MARK: -

class PersistingTests: SpineTests {

	// MARK: Delete
	
	func testDeleteResource() {
		HTTPClient.handler = { (request: NSURLRequest, payload: NSData?) -> (responseData: NSData, statusCode: Int, error: NSError?) in
			XCTAssertEqual(request.URL, NSURL(string:"http://example.com/bars/1")!, "Request URL not as expected.")
			XCTAssertEqual(request.HTTPMethod!, "DELETE", "Expected HTTP method to be 'DELETE'.")
			return (responseData: NSData(), statusCode: 204, error: nil)
		}
		
		let bar = Bar(id: "1")
		let expectation = expectationWithDescription("testDeleteResource")
		
		spine.delete(bar).onSuccess {
			expectation.fulfill()
		}.onFailure { error in
			expectation.fulfill()
			XCTFail("Delete failed with error: \(error).")
		}
		
		waitForExpectationsWithTimeout(10) { error in
			XCTAssertNil(error, "\(error)")
		}
	}
	
	func testDeleteResourceWithAPIError() {
		HTTPClient.respondWith(404)
		
		let bar = Bar(id: "1")
		let expectation = expectationWithDescription("testDeleteResource")
		let future = spine.delete(bar)
		assertFutureFailure(future, withErrorDomain: SPINE_API_ERROR_DOMAIN, errorCode: 404, expectation)
		
		waitForExpectationsWithTimeout(10) { error in
			XCTAssertNil(error, "\(error)")
		}
	}
	
	func testDeleteResourceWithNetworkError() {
		HTTPClient.respondWith(404, error: NSError(domain: "mock", code: 999, userInfo: nil))
		
		let bar = Bar(id: "1")
		let expectation = expectationWithDescription("testDeleteResource")
		let future = spine.delete(bar)
		assertFutureFailure(future, withErrorDomain: SPINE_ERROR_DOMAIN, errorCode: 999, expectation)
		
		waitForExpectationsWithTimeout(10) { error in
			XCTAssertNil(error, "\(error)")
		}
	}
	
	// MARK: Save
	
	//TODO
}
