//
//  Utilities.swift
//  Spine
//
//  Created by Ward van Teijlingen on 19-02-15.
//  Copyright (c) 2015 Ward van Teijlingen. All rights reserved.
//

import Foundation
import XCTest
import SwiftyJSON
import BrightFutures

extension XCTestCase {
	
	func JSONFixtureWithName(name: String) -> (data: NSData, json: JSON) {
		let path = NSBundle(forClass: self.dynamicType).URLForResource(name, withExtension: "json")!
		let data = NSData(contentsOfURL: path)!
		let json = JSON(data: data)
		return (data: data, json: json)
	}
}

func ISO8601FormattedDate(date: NSDate) -> String {
	let dateFormatter = NSDateFormatter()
	let enUSPosixLocale = NSLocale(localeIdentifier: "en_US_POSIX")
	dateFormatter.locale = enUSPosixLocale
	dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
	
	return dateFormatter.stringFromDate(date)
}

// MARK: - Custom assertions

func assertFutureSuccess<T, E>(future: Future<T, E>, expectation: XCTestExpectation) {
	future.onSuccess { resources in
		expectation.fulfill()
	}.onFailure { error in
		expectation.fulfill()
		XCTFail("Expected future to complete with success.")
	}
}

func assertFutureFailure<T>(future: Future<T, SpineError>, withError expectedError: SpineError, expectation: XCTestExpectation) {
	future.onSuccess { resources in
		expectation.fulfill()
		XCTFail("Expected success callback to not be called.")
	}.onFailure { error in
		expectation.fulfill()
		XCTAssertEqual(error, expectedError, "Expected error to be be \(expectedError).")
	}
}

func assertFutureFailure<T>(future: Future<T, SpineError>, withStatusCode code: Int, expectation: XCTestExpectation) {
	let expectedError = SpineError.ServerError(statusCode: code, apiErrors: nil)
	assertFutureFailure(future, withError: expectedError, expectation: expectation)
}

func assertFooResource(foo: Foo, isEqualToJSON json: JSON) {
	XCTAssertEqual(foo.stringAttribute!, json["attributes"]["string-attribute"].stringValue, "Deserialized string attribute is not equal.")
	XCTAssertEqual(foo.integerAttribute!, json["attributes"]["integer-attribute"].intValue, "Deserialized integer attribute is not equal.")
	XCTAssertEqual(foo.floatAttribute!, json["attributes"]["float-attribute"].floatValue, "Deserialized float attribute is not equal.")
	XCTAssertEqual(foo.booleanAttribute!, json["attributes"]["integer-attribute"].boolValue, "Deserialized boolean attribute is not equal.")
	XCTAssertNil(foo.nilAttribute, "Deserialized nil attribute is not equal.")
	XCTAssertEqual(foo.dateAttribute!, NSDate(timeIntervalSince1970: 0), "Deserialized date attribute is not equal.")
}