//
//  CallbackHTTPClient.swift
//  Spine
//
//  Created by Ward van Teijlingen on 27-02-15.
//  Copyright (c) 2015 Ward van Teijlingen. All rights reserved.
//

import Foundation

public class CallbackHTTPClient: _HTTPClientProtocol {
	typealias HandlerFunction = (request: NSURLRequest, payload: NSData?) -> (responseData: NSData, statusCode: Int, error: NSError?)
	
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
	
	func request(method: HTTPClientRequestMethod, URL: NSURL, payload: NSData?, callback: HTTPClientCallback) {
		let request = NSMutableURLRequest(URL: URL)
		request.HTTPMethod = method.rawValue
		
		if let payload = payload {
			request.HTTPBody = payload
		}
		
		trace("⬆️ \(method.rawValue): \(URL)")
		
		// Perform the request
		dispatch_async(queue) {
			let (data, statusCode, error) = self.handler(request: request, payload: payload)
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
	
	func respondWith(status: Int, data: NSData? = nil, error: NSError? = nil) {
		let responseData = data ?? NSData()
		handler = { request, payload in
			return (responseData: responseData, statusCode: status, error: error)
		}
	}
	
	private func trace<T>(object: T) {
		if traceEnabled {
			println(object)
		}
	}
}