//
//  Utilities.swift
//  Spine
//
//  Created by Ward van Teijlingen on 19-02-15.
//  Copyright (c) 2015 Ward van Teijlingen. All rights reserved.
//

import Foundation
import XCTest

extension XCTestCase {
	var testBundle: NSBundle {
		return NSBundle(forClass: self.dynamicType)
	}
}

public class CallbackHTTPClient: _HTTPClientProtocol {
	typealias HandlerFunction = (request: NSURLRequest, rawPayload: [String : AnyObject]?) -> (responseData: NSData, statusCode: Int, error: NSError?)
	
	var handler: HandlerFunction!
	var traceEnabled = false
	
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
		
		trace("⬆️ \(method.rawValue):  \(URL)")
		
		// Perform the request
		let (data, statusCode, error) = handler(request: request, rawPayload: payload)
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
	
	private func trace<T>(object: T) {
		if traceEnabled {
			println(object)
		}
	}
}