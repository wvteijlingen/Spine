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

func compareAttributesOfFooResource(foo: Foo, withJSON json: JSON) {
	XCTAssertEqual(foo.stringAttribute!, json["stringAttribute"].stringValue, "Deserialized string attribute is not equal.")
	XCTAssertEqual(foo.integerAttribute!, json["integerAttribute"].intValue, "Deserialized integer attribute is not equal.")
	XCTAssertEqual(foo.floatAttribute!, json["floatAttribute"].floatValue, "Deserialized float attribute is not equal.")
	XCTAssertEqual(foo.booleanAttribute!, json["integerAttribute"].boolValue, "Deserialized boolean attribute is not equal.")
	XCTAssertNil(foo.nilAttribute, "Deserialized nil attribute is not equal.")
	XCTAssertEqual(foo.dateAttribute!, NSDate(timeIntervalSince1970: 0), "Deserialized date attribute is not equal.")
}

extension XCTestCase {
	var testBundle: NSBundle {
		return NSBundle(forClass: self.dynamicType)
	}
}

public class CallbackHTTPClient: _HTTPClientProtocol {
	typealias HandlerFunction = (request: NSURLRequest, rawPayload: [String : AnyObject]?) -> (responseData: NSData, statusCode: Int, error: NSError?)
	
	var handler: HandlerFunction!
	var traceEnabled = false
	let queue = dispatch_queue_create("com.wardvanteijlingen.spine.callbackHTTPClient", nil)
	var delay: NSTimeInterval = 0
	
	init() {}
	
	public func setHeader(header: String, to value: String) {
		//
	}
	
	public func removeHeader(header: String) {
		//
	}
	
	func request(method: HTTPClientRequestMethod, URL: NSURL, callback: HTTPClientCallback) {
		return request(method, URL: URL, payload: nil, callback: callback)
	}
	
	// TODO: Move JSON serializing out of networking component
	func request(method: HTTPClientRequestMethod, URL: NSURL, payload: [String : AnyObject]?, callback: HTTPClientCallback) {
		let request = NSMutableURLRequest(URL: URL)
		request.HTTPMethod = method.rawValue
		
		if let payload = payload {
			request.HTTPBody = NSJSONSerialization.dataWithJSONObject(payload, options: NSJSONWritingOptions(0), error: nil)
		}
		
		trace("⬆️ \(method.rawValue): \(URL)")
		
		// Perform the request
		dispatch_async(queue) {
			let (data, statusCode, error) = self.handler(request: request, rawPayload: payload)
			let startTime = dispatch_time(DISPATCH_TIME_NOW, Int64(self.delay * Double(NSEC_PER_SEC)))
			
			dispatch_after(startTime, dispatch_get_main_queue()) {
				var resolvedError: NSError?
				
				// Framework error
				if let error = error {
					self.trace("❌ Err:  \(request.URL) - \(error.localizedDescription)")
					resolvedError = NSError(domain: SPINE_ERROR_DOMAIN, code: error.code, userInfo: error.userInfo)
					
					// Success
				} else if 200 ... 299 ~= statusCode {
					self.trace("✅ \(statusCode):  \(request.URL)")
					
					// API Error
				} else {
					self.trace("❌ \(statusCode):  \(request.URL)")
					resolvedError = NSError(domain: SPINE_API_ERROR_DOMAIN, code: statusCode, userInfo: nil)
				}
				
				callback(statusCode: statusCode, responseData: data, error: resolvedError)
			}
		}
	}
	
	private func trace<T>(object: T) {
		if traceEnabled {
			println(object)
		}
	}
}