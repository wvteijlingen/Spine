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
		let relationship = fieldWithName("toOneAttribute", ofResource: resource) as Relationship
		let URL = spine.router.URLForRelationship(relationship, ofResource: resource)
		
		let expectedURL = NSURL(string: "http://example.com/foos/1/links/toOneAttribute")!
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
