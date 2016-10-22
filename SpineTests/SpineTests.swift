//
//  SpineTests.swift
//  SpineTests
//
//  Created by Ward van Teijlingen on 30-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import XCTest
import SwiftyJSON
import BrightFutures

class SpineTests: XCTestCase {
	var spine: Spine!
	var HTTPClient: CallbackHTTPClient!
	
	override func setUp() {
		super.setUp()
		HTTPClient = CallbackHTTPClient()
		spine = Spine(baseURL: URL(string:"http://example.com")!, networkClient: HTTPClient)
		spine.registerResource(Foo.self)
		spine.registerResource(Bar.self)
		
		Spine.setLogLevel(.info, forDomain: .spine)
	}
}

// MARK: -

class FindAllTests: SpineTests {
	func testItShouldSucceed() {
		let fixture = JSONFixtureWithName("MultipleFoos")
		
		HTTPClient.handler = { request, payload in
			XCTAssertEqual(request.httpMethod!, "GET", "HTTP method not as expected.")
			XCTAssertEqual(request.url!, URL(string:"http://example.com/foos")!, "Request URL not as expected.")
			return (responseData: fixture.data, statusCode: 200, error: nil)
		}
		
		let expectation = self.expectation(description: "testFindByType")
		
		spine.findAll(Foo.self).onSuccess { fooCollection, _, _ in
			expectation.fulfill()
			for (index, resource) in fooCollection.enumerated() {
				XCTAssertEqual(fooCollection.count, 2, "Deserialized resources count not equal.")
				XCTAssert(resource is Foo, "Deserialized resource should be of class 'Foo'.")
				let foo = resource as! Foo
				assertFooResource(foo, isEqualToJSON: fixture.json["data"][index])
			}
			}.onFailure { error in
				expectation.fulfill()
				XCTFail("Find failed with error: \(error).")
		}
		
		waitForExpectations(timeout: 10) { error in
			XCTAssertNil(error, "\(error)")
		}
	}
	
	func testItShouldFailOnAPIError() {
		let fixture = JSONFixtureWithName("Errors")
		HTTPClient.respondWith(404, data: fixture.data)
		
		let expectation = self.expectation(description: "testFindByTypeWithAPIError")
		let future = spine.findAll(Foo.self)
		assertFutureFailureWithServerError(future, statusCode: 404, expectation: expectation)
		
		waitForExpectations(timeout: 10) { error in
			XCTAssertNil(error, "\(error)")
		}
	}
	
	func testItShouldFailOnNetworkError() {
		HTTPClient.simulateNetworkErrorWithCode(999)
		let expectation = self.expectation(description: "testFindByTypeWithNetworkError")
		let future = spine.findAll(Foo.self)
		
		assertFutureFailureWithNetworkError(future, code: 999, expectation: expectation)
		
		waitForExpectations(timeout: 10) { error in
			XCTAssertNil(error, "\(error)")
		}
	}
}

class FindByIDTests: SpineTests {
	
	func testItShouldSucceed() {
		let fixture = JSONFixtureWithName("MultipleFoos")
		
		HTTPClient.handler = { request, payload in
			XCTAssertEqual(request.httpMethod!, "GET", "HTTP method not as expected.")
			XCTAssertEqual(request.url!, URL(string:"http://example.com/foos?filter[id]=1,2")!, "Request URL not as expected.")
			return (responseData: fixture.data, statusCode: 200, error: nil)
		}
		
		let expectation = self.expectation(description: "testFindByIDAndType")
		
		spine.find(["1","2"], ofType: Foo.self).onSuccess { fooCollection, _, _ in
			expectation.fulfill()
			for (index, resource) in fooCollection.enumerated() {
				XCTAssertEqual(fooCollection.count, 2, "Expected resource count to be 2.")
				XCTAssert(resource is Foo, "Expected resource to be of class 'Foo'.")
				let foo = resource as! Foo
				assertFooResource(foo, isEqualToJSON: fixture.json["data"][index])
			}
			}.onFailure { error in
				expectation.fulfill()
				XCTFail("Find failed with error: \(error).")
		}
		
		waitForExpectations(timeout: 10) { error in
			XCTAssertNil(error, "\(error)")
		}
	}
	
	func testItShouldFailOnAPIError() {
		HTTPClient.respondWith(404)
		
		let expectation = self.expectation(description: "testFindByIDAndTypeWithAPIError")
		let future = spine.find(["1","2"], ofType: Foo.self)
		assertFutureFailureWithServerError(future, statusCode: 404, expectation: expectation)
		
		waitForExpectations(timeout: 10) { error in
			XCTAssertNil(error, "\(error)")
		}
	}
	
	func testItShouldFailOnNetworkError() {
		HTTPClient.simulateNetworkErrorWithCode(999)
		let expectation = self.expectation(description: "testFindByIDAndTypeWithNetworkError")
		let future = spine.find(["1","2"], ofType: Foo.self)
		
		assertFutureFailureWithNetworkError(future, code: 999, expectation: expectation)
		
		waitForExpectations(timeout: 10) { error in
			XCTAssertNil(error, "\(error)")
		}
	}
}

class FindOneByIDTests: SpineTests {
	func testItShouldSucceed() {
		let fixture = JSONFixtureWithName("SingleFoo")
		
		HTTPClient.handler = { request, payload in
			XCTAssertEqual(request.httpMethod!, "GET", "HTTP method not as expected.")
			XCTAssertEqual(request.url!, URL(string:"http://example.com/foos/1")!, "Request URL not as expected.")
			return (responseData: fixture.data, statusCode: 200, error: nil)
		}
		
		let expectation = self.expectation(description: "testFindOneByIDAndType")
		
		spine.findOne("1", ofType: Foo.self).onSuccess { foo, _, _ in
			expectation.fulfill()
			assertFooResource(foo, isEqualToJSON: fixture.json["data"])
			}.onFailure { error in
				expectation.fulfill()
				XCTFail("Find failed with error: \(error).")
		}
		
		waitForExpectations(timeout: 10) { error in
			XCTAssertNil(error, "\(error)")
		}
	}
	
	func testItShouldFailOnAPIError() {
		HTTPClient.respondWith(404)
		
		let expectation = self.expectation(description: "testFindOneByTypeWithAPIError")
		let future = spine.findOne("1", ofType: Foo.self)
		assertFutureFailureWithServerError(future, statusCode: 404, expectation: expectation)
		
		waitForExpectations(timeout: 10) { error in
			XCTAssertNil(error, "\(error)")
		}
	}
	
	func testItShouldFailOnNetworkError() {
		let networkError = HTTPClient.simulateNetworkErrorWithCode(999)
		let expectation = self.expectation(description: "testFindOneByTypeWithNetworkError")
		let future = spine.findOne("1", ofType: Foo.self)
		
		assertFutureFailure(future, withError: SpineError.networkError(networkError), expectation: expectation)
		
		waitForExpectations(timeout: 10) { error in
			XCTAssertNil(error, "\(error)")
		}
	}
}

class FindByQueryTests: SpineTests {
	func testItShouldSucceed() {
		let fixture = JSONFixtureWithName("MultipleFoos")
		
		HTTPClient.handler = { request, payload in
			XCTAssertEqual(request.httpMethod!, "GET", "HTTP method not as expected.")
			XCTAssertEqual(request.url!, URL(string:"http://example.com/foos?filter[id]=1,2")!, "Request URL not as expected.")
			return (responseData: fixture.data, statusCode: 200, error: nil)
		}
		
		let query = Query(resourceType: Foo.self, resourceIDs: ["1", "2"])
		let expectation = self.expectation(description: "testFindByQuery")
		
		spine.find(query).onSuccess { fooCollection, _, _ in
			expectation.fulfill()
			for (index, resource) in fooCollection.enumerated() {
				XCTAssertEqual(fooCollection.count, 2, "Deserialized resources count not equal.")
				XCTAssert(resource is Foo, "Deserialized resource should be of class 'Foo'.")
				let foo = resource as! Foo
				assertFooResource(foo, isEqualToJSON: fixture.json["data"][index])
			}
			}.onFailure { error in
				expectation.fulfill()
				XCTFail("Find failed with error: \(error).")
		}
		
		waitForExpectations(timeout: 10) { error in
			XCTAssertNil(error, "\(error)")
		}
	}
	
	func testItShouldFailOnAPIError() {
		HTTPClient.respondWith(404)
		
		let expectation = self.expectation(description: "testFindByQueryWithAPIError")
		
		let query = Query(resourceType: Foo.self, resourceIDs: ["1"])
		let future = spine.find(query)
		assertFutureFailureWithServerError(future, statusCode: 404, expectation: expectation)
		
		waitForExpectations(timeout: 10) { error in
			XCTAssertNil(error, "\(error)")
		}
	}
	
	func testItShouldFailOnNetworkError() {
		HTTPClient.simulateNetworkErrorWithCode(999)
		
		let expectation = self.expectation(description: "testFindByQueryWithNetworkError")
		
		let query = Query(resourceType: Foo.self, resourceIDs: ["1"])
		let future = spine.find(query)
		assertFutureFailureWithNetworkError(future, code: 999, expectation: expectation)
		
		waitForExpectations(timeout: 10) { error in
			XCTAssertNil(error, "\(error)")
		}
	}
}

class FindOneByQueryTests: SpineTests {
	func testItShouldSucceed() {
		let fixture = JSONFixtureWithName("SingleFoo")
		
		HTTPClient.handler = { request, payload in
			XCTAssertEqual(request.httpMethod!, "GET", "HTTP method not as expected.")
			XCTAssertEqual(request.url!, URL(string:"http://example.com/foos/1")!, "Request URL not as expected.")
			return (responseData: fixture.data, statusCode: 200, error: nil)
		}
		
		let query = Query(resourceType: Foo.self, resourceIDs: ["1"])
		let expectation = self.expectation(description: "testFindOneByQuery")
		
		spine.findOne(query).onSuccess { foo, _, _ in
			expectation.fulfill()
			assertFooResource(foo, isEqualToJSON: fixture.json["data"])
			}.onFailure { error in
				expectation.fulfill()
				XCTFail("Find failed with error: \(error).")
		}
		
		waitForExpectations(timeout: 10) { error in
			XCTAssertNil(error, "\(error)")
		}
	}
	
	func testItShouldFailOnAPIError() {
		HTTPClient.respondWith(404)
		
		let expectation = self.expectation(description: "testFindOneByQueryWithAPIError")
		
		let query = Query(resourceType: Foo.self, resourceIDs: ["1"])
		let future = spine.findOne(query)
		assertFutureFailureWithServerError(future, statusCode: 404, expectation: expectation)
		
		waitForExpectations(timeout: 10) { error in
			XCTAssertNil(error, "\(error)")
		}
	}
	
	func testItShouldFailOnNetworkError() {
		HTTPClient.simulateNetworkErrorWithCode(999)
		
		let expectation = self.expectation(description: "testFindOneByQueryWithNetworkError")
		
		let query = Query(resourceType: Foo.self, resourceIDs: ["1"])
		let future = spine.findOne(query)
		assertFutureFailureWithNetworkError(future, code: 999, expectation: expectation)
		
		waitForExpectations(timeout: 10) { error in
			XCTAssertNil(error, "\(error)")
		}
	}

}

class DeleteTests: SpineTests {
	
	func testItShouldSucceed() {
		HTTPClient.handler = { request, payload in
			XCTAssertEqual(request.url!, URL(string:"http://example.com/bars/1")!, "Request URL not as expected.")
			XCTAssertEqual(request.httpMethod!, "DELETE", "Expected HTTP method to be 'DELETE'.")
			return (responseData: Data(), statusCode: 204, error: nil)
		}
		
		let bar = Bar(id: "1")
		let expectation = self.expectation(description: "testDeleteResource")
		
		spine.delete(bar).onSuccess {
			expectation.fulfill()
		}.onFailure { error in
			expectation.fulfill()
			XCTFail("Delete failed with error: \(error).")
		}
		
		waitForExpectations(timeout: 10) { error in
			XCTAssertNil(error, "\(error)")
		}
	}
	
	func testItShouldFailOnAPIError() {
		HTTPClient.respondWith(404)
		
		let bar = Bar(id: "1")
		let expectation = self.expectation(description: "testDeleteResourceWithAPIError")
		let future = spine.delete(bar)
		assertFutureFailureWithServerError(future, statusCode: 404, expectation: expectation)
		
		waitForExpectations(timeout: 10) { error in
			XCTAssertNil(error, "\(error)")
		}
	}
	
	func testItShouldFailOnNetworkError() {
		HTTPClient.simulateNetworkErrorWithCode(999)
		
		let bar = Bar(id: "1")
		let expectation = self.expectation(description: "testDeleteResourceWithNetworkError")
		let future = spine.delete(bar)
		assertFutureFailureWithNetworkError(future, code: 999, expectation: expectation)
		
		waitForExpectations(timeout: 10) { error in
			XCTAssertNil(error, "\(error)")
		}
	}
	
}

class SaveTests: SpineTests {
	
	var fixture: (data: Data, json: JSON)!
	var foo: Foo!
	
	override func setUp() {
		super.setUp()

		fixture = JSONFixtureWithName("SingleFoo")

		do {
			let document = try spine.serializer.deserializeData(fixture.data)
			foo = document.data!.first as! Foo
		} catch let error as NSError {
			XCTFail("Deserialisation failed with error: \(error).")
		}
	}
	
//	func testItShouldPOSTWhenCreatingANewResource() {
//		HTTPClient.handler = { request, payload in
//			XCTAssertEqual(request.httpMethod!, "POST", "HTTP method not as expected.")
//			XCTAssertEqual(request.url!, URL(string:"http://example.com/foos")!, "Request URL not as expected.")
//			return (responseData: self.fixture.data, statusCode: 201, error: nil)
//		}
//
//		foo = Foo()
//		let future = spine.save(foo)
//		let expectation = self.expectation(description: "")
//		assertFutureSuccess(future, expectation: expectation)
//		
//		waitForExpectations(timeout: 10) { error in
//			XCTAssertNil(error, "\(error)")
//		}
//	}

	func testClientGeneratedId() {
		HTTPClient.handler = { request, payload in
			XCTAssertEqual(request.httpMethod!, "POST", "HTTP method not as expected.")
			XCTAssertEqual(request.url!, URL(string:"http://example.com/foos")!, "Request URL not as expected.")
			let json = JSON(data: payload!)
			XCTAssertEqual(json["data"]["id"].stringValue, "some id")
			return (responseData: self.fixture.data, statusCode: 201, error: nil)
		}

		foo = Foo()

		spine.idGenerator = { resource in
			"some id"
		}

		let future = spine.save(foo)
		let expectation = self.expectation(description: "")
		assertFutureSuccess(future, expectation: expectation)

		waitForExpectations(timeout: 10) { error in
			XCTAssertNil(error, "\(error)")
		}
	}

	func testItShouldPATCHWhenUpdatingAResource() {
		var resourcePatched = false
		
		HTTPClient.handler = { request, payload in
			XCTAssertEqual(request.httpMethod!, "PATCH", "HTTP method not as expected.")
			if(request.url! == URL(string: "http://example.com/foos/1")!) {
				resourcePatched = true
			}
			return (responseData: self.fixture.data, statusCode: 201, error: nil)
		}

		let future = spine.save(foo)
		let expectation = self.expectation(description: "")
		assertFutureSuccess(future, expectation: expectation)
		
		waitForExpectations(timeout: 10) { error in
			XCTAssertNil(error, "\(error)")
			XCTAssertTrue(resourcePatched)
		}
	}

	func testNoClientGeneratedIdWhenUpdating() {
		var resourcePatched = false

		HTTPClient.handler = { request, payload in
			XCTAssertEqual(request.httpMethod!, "PATCH", "HTTP method not as expected.")
			if(request.url! == URL(string: "http://example.com/foos/1")!) {
				resourcePatched = true
				let json = JSON(data: payload!)
				XCTAssertEqual(json["data"]["id"].stringValue, self.foo.id)
			}
			return (responseData: self.fixture.data, statusCode: 201, error: nil)
		}

		spine.idGenerator = { r in
			XCTFail("Id generator function must not be called when updating a resource")
			return "some id"
		}

		let future = spine.save(foo)
		let expectation = self.expectation(description: "")
		assertFutureSuccess(future, expectation: expectation)

		waitForExpectations(timeout: 10) { error in
			XCTAssertNil(error, "\(error)")
			XCTAssertTrue(resourcePatched)
		}
	}

	func testItShouldFailOnAPIError() {
		HTTPClient.respondWith(400)
		
		let expectation = self.expectation(description: "testCreateResourceWithAPIError")
		let future = spine.save(foo)
		assertFutureFailureWithServerError(future, statusCode: 400, expectation: expectation)

		waitForExpectations(timeout: 10) { error in
			XCTAssertNil(error, "\(error)")
		}
	}
	
	func testItShouldFailOnNetworkError() {
		HTTPClient.simulateNetworkErrorWithCode(999)
		
		let expectation = self.expectation(description: "testDeleteResourceWithNetworkError")
		let future = spine.save(foo)
		assertFutureFailureWithNetworkError(future, code: 999, expectation: expectation)
		
		waitForExpectations(timeout: 10) { error in
			XCTAssertNil(error, "\(error)")
		}
	}
}

class SaveRelationshipsTests: SpineTests {

	var fixture: (data: Data, json: JSON)!
	var foo: Foo!

	override func setUp() {
		super.setUp()

		fixture = JSONFixtureWithName("SingleFooIncludingBars")

		do {
			let document = try spine.serializer.deserializeData(fixture.data)
			foo = document.data!.first as! Foo
		} catch let error as NSError {
			XCTFail("Deserialisation failed with error: \(error).")
		}
	}

	func testItShouldPATCHToOneRelationships() {
		var relationshipUpdated = false

		HTTPClient.handler = { request, payload in
			if(request.httpMethod! == "PATCH" && request.url!.absoluteString == "http://example.com/foos/1/relationships/to-one-attribute") {
				let json = JSON(data: payload!)
				if json["data"]["type"].string == "bars" && json["data"]["id"].string == "10" {
					relationshipUpdated = true
				}
			}
			return (responseData: self.fixture.data, statusCode: 201, error: nil)
		}

		let future = spine.save(foo)
		let expectation = self.expectation(description: "")
		assertFutureSuccess(future, expectation: expectation)

		waitForExpectations(timeout: 10) { error in
			XCTAssertNil(error, "\(error)")
			XCTAssertTrue(relationshipUpdated)
		}
	}
	
	func testItShouldPATCHToOneRelationshipsWithNull() {
		var relationshipUpdated = false
		
		HTTPClient.handler = { request, payload in
			if(request.httpMethod! == "PATCH" && request.url!.absoluteString == "http://example.com/foos/1/relationships/to-one-attribute") {
				let json = JSON(data: payload!)
				if json["data"].type == .null {
					relationshipUpdated = true
				}
			}
			return (responseData: self.fixture.data, statusCode: 201, error: nil)
		}
		
		foo.toOneAttribute = nil
		
		let future = spine.save(foo)
		let expectation = self.expectation(description: "")
		assertFutureSuccess(future, expectation: expectation)
		
		waitForExpectations(timeout: 10) { error in
			XCTAssertNil(error, "\(error)")
			XCTAssertTrue(relationshipUpdated)
		}
	}

	func testItShouldPOSTToManyRelationships() {
		var relationshipUpdated = false

		HTTPClient.handler = { request, payload in
			if(request.httpMethod! == "POST" && request.url!.absoluteString == "http://example.com/foos/1/relationships/to-many-attribute") {
				let data = JSON(data: payload!)["data"].arrayValue
				XCTAssertEqual(data.count, 1, "Expected data count to be 1.")

				if data[0]["type"].string == "bars" && data[0]["id"].string == "13" {
					relationshipUpdated = true
				}
			}
			return (responseData: self.fixture.data, statusCode: 201, error: nil)
		}

		let bar = Bar(id: "13")
		foo.toManyAttribute!.linkResource(bar)

		let future = spine.save(foo)
		let expectation = self.expectation(description: "")
		assertFutureSuccess(future, expectation: expectation)

		waitForExpectations(timeout: 10) { error in
			XCTAssertNil(error, "\(error)")
			XCTAssertTrue(relationshipUpdated)
		}
	}

	func testItShouldDELETEToManyRelationships() {
		var relationshipUpdated = false

		HTTPClient.handler = { request, payload in
			if(request.httpMethod! == "DELETE" && request.url!.absoluteString == "http://example.com/foos/1/relationships/to-many-attribute") {
				let data = JSON(data: payload!)["data"].arrayValue
				XCTAssertEqual(data.count, 1, "Expected data count to be 1.")

				if data[0]["type"].string == "bars" && data[0]["id"].string == "11" {
					relationshipUpdated = true
				}
			}
			return (responseData: self.fixture.data, statusCode: 201, error: nil)
		}

		let bar = foo.toManyAttribute!.resources.first!
		foo.toManyAttribute!.unlinkResource(bar)

		let future = spine.save(foo)
		let expectation = self.expectation(description: "")
		assertFutureSuccess(future, expectation: expectation)

		waitForExpectations(timeout: 10) { error in
			XCTAssertNil(error, "\(error)")
			XCTAssertTrue(relationshipUpdated)
		}
	}

	func testItShouldFailOnAPIError() {
		HTTPClient.handler = { request, payload in
			if(request.httpMethod! == "PATCH" && request.url!.absoluteString == "http://example.com/foos/1/relationships/to-one-attribute") {
				return (responseData: nil, statusCode: 422, error: nil)
			}
			return (responseData: self.fixture.data, statusCode: 201, error: nil)
		}

		foo.toOneAttribute = nil

		let expectation = self.expectation(description: "")
		let future = spine.save(foo)
		assertFutureFailureWithServerError(future, statusCode: 422, expectation: expectation)

		waitForExpectations(timeout: 10) { error in
			XCTAssertNil(error, "\(error)")
		}
	}
}

class PaginatingTests: SpineTests {
	func testLoadNextPageInCollection() {
		let fixture = JSONFixtureWithName("PagedFoos-2")
		let nextURL = URL(string: "http://example.com/foos?page[limit]=2&page[number]=2")!
		
		HTTPClient.handler = { request, payload in
			XCTAssertEqual(request.url!, nextURL, "Request URL not as expected.")
			return (responseData: fixture.data, statusCode: 200, error: nil)
		}
		
		let collection = ResourceCollection(resources: [Foo(id: "1"), Foo(id: "2")], resourcesURL: URL(string: "http://example.com/foos?page[limit]=2")!)
		collection.nextURL = nextURL
		
		let expectation = self.expectation(description: "testLoadNextPageInCollection")
		
		spine.loadNextPageOfCollection(collection).onSuccess { collection in
			expectation.fulfill()
			XCTAssertEqual(collection.count, 4, "Expected count to be 4.")
			XCTAssertEqual(collection.resourcesURL!, nextURL, "Expected resourcesURL to be updated to new page")
			XCTAssertEqual(collection.previousURL!, URL(string: "http://example.com/foos?page[limit]=2")!, "Expected previousURL to be updated to previous page")
			XCTAssertNil(collection.nextURL, "Expected nextURL to be nil.")
			
		}.onFailure { error in
			expectation.fulfill()
			XCTFail("Loading failed with error: \(error).")
		}
		
		waitForExpectations(timeout: 10) { error in
			XCTAssertNil(error, "\(error)")
		}
	}
	
	func testLoadPreviousPageInColleciton() {
		let fixture = JSONFixtureWithName("PagedFoos-1")
		
		HTTPClient.handler = { request, payload in
			XCTAssertEqual(request.url!, URL(string: "http://example.com/foos?page[limit]=2")!, "Request URL not as expected.")
			return (responseData: fixture.data, statusCode: 200, error: nil)
		}
		
		
		let secondPageResources = [Foo(id: "3"), Foo(id: "4")]
		let collection = ResourceCollection(resources: secondPageResources, resourcesURL: URL(string: "http://example.com/foos?page[limit]=2")!)
		collection.previousURL = URL(string: "http://example.com/foos?page[limit]=2")!
		
		let expectation = self.expectation(description: "testLoadPreviousPageInColleciton")
		
		spine.loadPreviousPageOfCollection(collection).onSuccess { collection in
			expectation.fulfill()
			XCTAssertEqual(collection.count, 4, "Expected count to be 4.")
			
			}.onFailure { error in
				expectation.fulfill()
				XCTFail("Loading failed with error: \(error).")
		}
		
		waitForExpectations(timeout: 10) { error in
			XCTAssertNil(error, "\(error)")
		}
	}
}
