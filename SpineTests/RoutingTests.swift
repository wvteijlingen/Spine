//
//  RoutingTests.swift
//  Spine
//
//  Created by Ward van Teijlingen on 19-02-15.
//  Copyright (c) 2015 Ward van Teijlingen. All rights reserved.
//

import UIKit
import XCTest

class RoutingTests: XCTestCase {
	let spine = Spine(baseURL: NSURL(string:"http://example.com")!)

	func testURLForResourceType() {
		let URL = spine.router.URLForResourceType("foos")
		let expectedURL = NSURL(string: "http://example.com/foos")!
		XCTAssertEqual(URL, expectedURL, "URL not as expected.")
	}
	
	func testURLForRelationship() {
		let resource = Foo(id: "1")
		let URL = spine.router.URLForRelationship("relatedBars", ofResource: resource)
		let expectedURL = NSURL(string: "http://example.com/foos/1/links/relatedBars")!
		XCTAssertEqual(URL, expectedURL, "URL not as expected.")
	}
	
	func testURLForRelationshipWithIDs() {
		let resource = Foo(id: "1")
		let URL = spine.router.URLForRelationship("relatedBars", ofResource: resource, ids: ["5", "6", "7"])
		let expectedURL = NSURL(string: "http://example.com/foos/1/links/relatedBars/5,6,7")!
		XCTAssertEqual(URL, expectedURL, "URL not as expected.")
	}
	
	func testURLForQuery() {
		var query = Query(resourceType: Foo.self, resourceIDs: ["1", "2"])
		query.include("firstInclude", "secondInclude")
		query.whereProperty("equalProperty", equalTo: "equalValue")
		query.restrictPropertiesTo("firstField", "secondField")
		query.addAscendingOrder("ascendingSort")
		query.addDescendingOrder("descendingSort")
		
		let URL = spine.router.URLForQuery(query)
		let expectedURL = NSURL(string: "http://example.com/foos/?filter[id]=1,2&include=firstInclude,secondInclude&filter[equalProperty]=equalValue&fields[foos]=firstField,secondField&sort=+ascendingSort,-descendingSort")!
		
		XCTAssertEqual(URL, expectedURL, "URL not as expected.")
	}
}
