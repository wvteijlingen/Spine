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
	
	func JSONFixtureWithName(_ name: String) -> (data: Data, json: JSON) {
		let path = Bundle(for: type(of: self)).url(forResource: name, withExtension: "json")!
		let data = try! Data(contentsOf: path)
		let json = JSON(data: data)
		return (data: data, json: json)
	}
}

func ISO8601FormattedDate(_ date: Date) -> String {
	let dateFormatter = DateFormatter()
	let enUSPosixLocale = Locale(identifier: "en_US_POSIX")
	dateFormatter.locale = enUSPosixLocale
	dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
	
	return dateFormatter.string(from: date)
}

// MARK: - Custom assertions

func assertFutureSuccess<T, E>(_ future: Future<T, E>, expectation: XCTestExpectation) {
	future.onSuccess { resources in
		expectation.fulfill()
	}.onFailure { error in
		expectation.fulfill()
		XCTFail("Expected future to complete with success.")
	}
}

func assertFutureFailure<T>(_ future: Future<T, SpineError>, withError expectedError: SpineError, expectation: XCTestExpectation) {
	future.onSuccess { resources in
		expectation.fulfill()
		XCTFail("Expected success callback to not be called.")
	}.onFailure { error in
		expectation.fulfill()
		XCTAssertEqual(error, expectedError, "Expected error to be be \(expectedError).")
	}
}

func assertFutureFailureWithServerError<T>(_ future: Future<T, SpineError>, statusCode code: Int, expectation: XCTestExpectation) {
	future.onSuccess { resources in
		expectation.fulfill()
		XCTFail("Expected success callback to not be called.")
		}.onFailure { error in
			expectation.fulfill()
			switch error {
			case .serverError(let statusCode, _):
				XCTAssertEqual(statusCode, code, "Expected error to be be .ServerError with statusCode \(code)")
			default:
				XCTFail("Expected error to be be .ServerError")
			}
	}
}

func assertFutureFailureWithNetworkError<T>(_ future: Future<T, SpineError>, code: Int, expectation: XCTestExpectation) {
	future.onSuccess { resources in
		expectation.fulfill()
		XCTFail("Expected success callback to not be called.")
	}.onFailure { error in
		expectation.fulfill()
		switch error {
		case .networkError(let error):
			XCTAssertEqual(error.code, code, "Expected error to be be .NetworkError with code \(code)")
		default:
			XCTFail("Expected error to be be .NetworkError")
		}
	}
}

func assertFooResource(_ foo: Foo, isEqualToJSON json: JSON) {
	XCTAssertEqual(foo.stringAttribute!, json["attributes"]["string-attribute"].stringValue, "Deserialized string attribute is not equal.")
	XCTAssertEqual(foo.integerAttribute?.intValue, json["attributes"]["integer-attribute"].intValue, "Deserialized integer attribute is not equal.")
	XCTAssertEqual(foo.floatAttribute?.floatValue, json["attributes"]["float-attribute"].floatValue, "Deserialized float attribute is not equal.")
	XCTAssertEqual(foo.booleanAttribute?.boolValue, json["attributes"]["integer-attribute"].boolValue, "Deserialized boolean attribute is not equal.")
	XCTAssertNil(foo.nilAttribute, "Deserialized nil attribute is not equal.")
	XCTAssertEqual(foo.dateAttribute! as Date, Date(timeIntervalSince1970: 0), "Deserialized date attribute is not equal.")
}
