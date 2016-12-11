//
//  RoutingTests.swift
//  Spine
//
//  Created by Ward van Teijlingen on 19-02-15.
//  Copyright (c) 2015 Ward van Teijlingen. All rights reserved.
//

import XCTest

class RoutingTests: XCTestCase {
	let spine = Spine(baseURL: URL(string:"http://example.com")!)

	func testURLForResourceType() {
		let url = spine.router.urlForResourceType("foos")
		let expectedURL = URL(string: "http://example.com/foos")!
		XCTAssertEqual(url, expectedURL, "URL not as expected.")
	}

	func testURLForQuery() {
		var query = Query(resourceType: Foo.self, resourceIDs: ["1", "2"])
		query.include("toOneAttribute", "toManyAttribute")
		query.whereAttribute("stringAttribute", equalTo: "stringValue")
		query.restrictFieldsTo("stringAttribute", "integerAttribute")
		query.restrictFieldsOfResourceType(Bar.self, to: "barStringAttribute")
		query.addAscendingOrder("integerAttribute")
		query.addDescendingOrder("floatAttribute")
		
		let url = spine.router.urlForQuery(query)
		let expectedURL = URL(string: "http://example.com/foos?filter[id]=1,2&include=to-one-attribute,to-many-attribute&filter[string-attribute]=stringValue&fields[foos]=string-attribute,integer-attribute&fields[bars]=bar-string-attribute&sort=integer-attribute,-float-attribute")!
		
		XCTAssertEqual(url, expectedURL, "URL not as expected.")
	}
    
	func testURLForQueryWithNonAttributeFilter() {
		var query = Query(resourceType: Foo.self, resourceIDs: ["1", "2"])
		query.addPredicateWithKey("notAnAttribute", value: "stringValue", type: .equalTo)

		let url = spine.router.urlForQuery(query)
		let expectedURL = URL(string: "http://example.com/foos?filter[id]=1,2&filter[notAnAttribute]=stringValue")!

		XCTAssertEqual(url, expectedURL, "URL not as expected.")
	}
	
	func testURLForQueryWithArrayFilter() {
		var query = Query(resourceType: Foo.self)
		query.whereAttribute("stringAttribute", equalTo: ["stringValue1", "stringValue2"])
		
		let url = spine.router.urlForQuery(query)
		let expectedURL = URL(string: "http://example.com/foos?filter[string-attribute]=stringValue1,stringValue2")!
		
		XCTAssertEqual(url, expectedURL, "URL not as expected.")
	}
	
	func testPagePagination() {
		var query = Query(resourceType: Foo.self)
		query.paginate(PageBasedPagination(pageNumber: 1, pageSize: 5))
		
		let url = spine.router.urlForQuery(query)
		let expectedURL = URL(string: "http://example.com/foos?page[number]=1&page[size]=5")!
		
		XCTAssertEqual(url, expectedURL, "URL not as expected.")
	}
	
	func testOffsetPagination() {
		var query = Query(resourceType: Foo.self)
		query.paginate(OffsetBasedPagination(offset: 20, limit: 5))
		
		let url = spine.router.urlForQuery(query)
		let expectedURL = URL(string: "http://example.com/foos?page[offset]=20&page[limit]=5")!
		
		XCTAssertEqual(url, expectedURL, "URL not as expected.")
	}
}
