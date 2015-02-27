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
	var testBundle: NSBundle {
		return NSBundle(forClass: self.dynamicType)
	}
}

// MARK: - Custom assertions

func assertFutureFailure<T>(future: Future<T>, withError expectedError: NSError, expectation: XCTestExpectation) {
	future.onSuccess { resources in
		expectation.fulfill()
		XCTFail("Expected success callback to not be called.")
		}.onFailure { error in
			expectation.fulfill()
			XCTAssertEqual(error.domain, expectedError.domain, "Expected error domain to be \(expectedError.domain).")
			XCTAssertEqual(error.code, expectedError.code, "Expected error code to be \(expectedError.code).")
	}
}

func assertFutureFailure<T>(future: Future<T>, withErrorDomain domain: String, errorCode code: Int, expectation: XCTestExpectation) {
	let expectedError = NSError(domain: domain, code: code, userInfo: nil)
	assertFutureFailure(future, withError: expectedError, expectation)
}

func assertFooResource(foo: Foo, isEqualToJSON json: JSON) {
	XCTAssertEqual(foo.stringAttribute!, json["stringAttribute"].stringValue, "Deserialized string attribute is not equal.")
	XCTAssertEqual(foo.integerAttribute!, json["integerAttribute"].intValue, "Deserialized integer attribute is not equal.")
	XCTAssertEqual(foo.floatAttribute!, json["floatAttribute"].floatValue, "Deserialized float attribute is not equal.")
	XCTAssertEqual(foo.booleanAttribute!, json["integerAttribute"].boolValue, "Deserialized boolean attribute is not equal.")
	XCTAssertNil(foo.nilAttribute, "Deserialized nil attribute is not equal.")
	XCTAssertEqual(foo.dateAttribute!, NSDate(timeIntervalSince1970: 0), "Deserialized date attribute is not equal.")
}