//
//  QueryTests.swift
//  Spine
//
//  Created by Ward van Teijlingen on 20-02-15.
//  Copyright (c) 2015 Ward van Teijlingen. All rights reserved.
//

import Foundation
import XCTest

class QueryInitializationTests: XCTestCase {
	func testInitWithResourceTypeAndIDs() {
		let query = Query(resourceType: Foo.self, resourceIDs: ["1", "2", "3"])
		XCTAssertEqual(query.resourceType, Foo.resourceType, "Resource type not as expected")
		XCTAssertEqual(query.resourceIDs!, ["1", "2", "3"], "Resource IDs type not as expected")
	}
	
	func testInitWithResource() {
		let foo = Foo(id: "5")
		let query = Query(resource: foo)
		
		XCTAssertEqual(query.resourceType, foo.resourceType, "Resource type not as expected")
		XCTAssertEqual(query.resourceIDs!, [foo.id!], "Resource IDs type not as expected")
	}
	
	//	func testInitWithResourceCollection() {
	//		let URL = NSURL(string: "http://example.com/foos")!
	//		let collection = ResourceCollection(resourcesURL: URL, resources: [])
	//		let query = Query(resourceCollection: collection)
	//
	//		XCTAssertEqual(query.URL!, collection.resourceURL, "URL not as expected")
	//	}
	
	func testInitWithResourceTypeAndURLString() {
		let urlString = "http://example.com/foos"
		let query = Query(resourceType: Foo.self, path: urlString)
		
		XCTAssertEqual(query.url!, URL(string: urlString)!, "URL not as expected")
		XCTAssertEqual(query.resourceType, Foo.resourceType, "Resource type not as expected")
	}
}

class QueryIncludeTests: XCTestCase {

	func testInclude() {
		var query = Query(resourceType: Foo.self)
		
		query.include("toOneAttribute", "toManyAttribute")
		XCTAssertEqual(query.includes, ["toOneAttribute", "toManyAttribute"], "Includes not as expected")
	}
	
	func testRemoveInclude() {
		var query = Query(resourceType: Foo.self)
		
		query.include("toOneAttribute", "toManyAttribute")
		query.removeInclude("toManyAttribute")
		XCTAssertEqual(query.includes, ["toOneAttribute"], "Includes not as expected")
	}
}

class QueryFilterTests: XCTestCase {

	func testWherePropertyEqualTo() {
		var query = Query(resourceType: Foo.self)
		query.whereAttribute("stringAttribute", equalTo: "value")
		
		let predicate = NSComparisonPredicate(
			leftExpression: NSExpression(forKeyPath: "stringAttribute"),
			rightExpression: NSExpression(forConstantValue: "value"),
			modifier: .direct,
			type: .equalTo,
			options: NSComparisonPredicate.Options())
		
		XCTAssertEqual(query.filters, [predicate], "Filters not as expected")
	}
	
	func testWherePropertyNotEqualTo() {
		var query = Query(resourceType: Foo.self)
		query.whereAttribute("stringAttribute", notEqualTo: "value")
		
		let predicate = NSComparisonPredicate(
			leftExpression: NSExpression(forKeyPath: "stringAttribute"),
			rightExpression: NSExpression(forConstantValue: "value"),
			modifier: .direct,
			type: .notEqualTo,
			options: NSComparisonPredicate.Options())
		
		XCTAssertEqual(query.filters, [predicate], "Filters not as expected")
	}
	
	func testWherePropertyLessThan() {
		var query = Query(resourceType: Foo.self)
		query.whereAttribute("integerAttribute", lessThan: "10")
		
		let predicate = NSComparisonPredicate(
			leftExpression: NSExpression(forKeyPath: "integerAttribute"),
			rightExpression: NSExpression(forConstantValue: "10"),
			modifier: .direct,
			type: .lessThan,
			options: NSComparisonPredicate.Options())
		
		XCTAssertEqual(query.filters, [predicate], "Filters not as expected")
	}
	
	func testWherePropertyLessThanOrEqualTo() {
		var query = Query(resourceType: Foo.self)
		query.whereAttribute("integerAttribute", lessThanOrEqualTo: "10")
		
		let predicate = NSComparisonPredicate(
			leftExpression: NSExpression(forKeyPath: "integerAttribute"),
			rightExpression: NSExpression(forConstantValue: "10"),
			modifier: .direct,
			type: .lessThanOrEqualTo,
			options: NSComparisonPredicate.Options())
		
		XCTAssertEqual(query.filters, [predicate], "Filters not as expected")
	}
	
	func testWherePropertyGreaterThan() {
		var query = Query(resourceType: Foo.self)
		query.whereAttribute("integerAttribute", greaterThan: "10")
		
		let predicate = NSComparisonPredicate(
			leftExpression: NSExpression(forKeyPath: "integerAttribute"),
			rightExpression: NSExpression(forConstantValue: "10"),
			modifier: .direct,
			type: .greaterThan,
			options: NSComparisonPredicate.Options())
		
		XCTAssertEqual(query.filters, [predicate], "Filters not as expected")
	}
	
	func testWherePropertyGreaterThanOrEqualTo() {
		var query = Query(resourceType: Foo.self)
		query.whereAttribute("integerAttribute", greaterThanOrEqualTo: "10")
		
		let predicate = NSComparisonPredicate(
			leftExpression: NSExpression(forKeyPath: "integerAttribute"),
			rightExpression: NSExpression(forConstantValue: "10"),
			modifier: .direct,
			type: .greaterThanOrEqualTo,
			options: NSComparisonPredicate.Options())
		
		XCTAssertEqual(query.filters, [predicate], "Filters not as expected")
	}
	
	func testWhereRelationshipIsOrContains() {
		let bar = Bar()
		bar.id = "3"
		
		var query = Query(resourceType: Foo.self)
		query.whereRelationship("toOneAttribute", isOrContains: bar)
		
		let predicate = NSComparisonPredicate(
			leftExpression: NSExpression(forKeyPath: "toOneAttribute"),
			rightExpression: NSExpression(forConstantValue: bar.id!),
			modifier: .direct,
			type: .equalTo,
			options: NSComparisonPredicate.Options())
		
		XCTAssertEqual(query.filters, [predicate], "Filters not as expected")
	}
	
	func testAddPredicateWithKey() {
		var query = Query(resourceType: Foo.self)
		query.addPredicateWithKey("notAnAttribute", value: "value", type: .equalTo)
		
		let predicate = NSComparisonPredicate(
				leftExpression: NSExpression(forKeyPath: "notAnAttribute"),
				rightExpression: NSExpression(forConstantValue: "value"),
				modifier: .direct,
				type: .equalTo,
				options: NSComparisonPredicate.Options())
		
		XCTAssertEqual(query.filters, [predicate], "Filters not as expected")
	}
}

class QuerySparseFieldsetsTests: XCTestCase {

	func testRestrictPropertiesTo() {
		var query = Query(resourceType: Foo.self)
		query.restrictFieldsTo("stringAttribute", "integerAttribute")
		
		XCTAssertNotNil(query.fields[Foo.resourceType])
		XCTAssertEqual(query.fields[Foo.resourceType]!, ["stringAttribute", "integerAttribute"], "Fields not as expected")
	}
	
	func testRestrictPropertiesOfResourceTypeTo() {
		var query = Query(resourceType: Foo.self)
		query.restrictFieldsOfResourceType(Bar.self, to: "barStringAttribute", "barIntegerAttribute")
		
		XCTAssertNotNil(query.fields["bars"])
		XCTAssertEqual(query.fields["bars"]!, ["barStringAttribute", "barIntegerAttribute"], "Fields not as expected")
	}
}

class QuerySortOrderTests: XCTestCase {

	func testAddAscendingOrder() {
		var query = Query(resourceType: Foo.self)
		query.addAscendingOrder("integerAttribute")
		
		let sortDescriptor = NSSortDescriptor(key: "integerAttribute", ascending: true)
		
		XCTAssertEqual(query.sortDescriptors, [sortDescriptor], "Sort descriptors not as expected")
	}
	
	func testAddDescendingOrder() {
		var query = Query(resourceType: Foo.self)
		query.addDescendingOrder("integerAttribute")
		
		let sortDescriptor = NSSortDescriptor(key: "integerAttribute", ascending: false)
		
		XCTAssertEqual(query.sortDescriptors, [sortDescriptor], "Sort descriptors not as expected")
	}
}
