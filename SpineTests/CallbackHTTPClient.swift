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
	var delay: NSTimeInterval = 0
	internal private(set) var lastRequest: NSURLRequest?
	let queue = dispatch_queue_create("com.wardvanteijlingen.spine.callbackHTTPClient", nil)
	
	init() {}
	
	public func setHeader(header: String, to value: String) {
		//
	}
	
	public func removeHeader(header: String) {
		//
	}
	
	func request(method: String, URL: NSURL, callback: HTTPClientCallback) {
		return request(method, URL: URL, payload: nil, callback: callback)
	}
	
	func request(method: String, URL: NSURL, payload: NSData?, callback: HTTPClientCallback) {
		let request = NSMutableURLRequest(URL: URL)
		request.HTTPMethod = method
		
		if let payload = payload {
			request.HTTPBody = payload
		}
		
		lastRequest = request
		Spine.logInfo(.Networking, "\(method): \(URL)")
		
		// Perform the request
		dispatch_async(queue) {
			let (data, statusCode, error) = self.handler(request: request, payload: payload)
			let startTime = dispatch_time(DISPATCH_TIME_NOW, Int64(self.delay * Double(NSEC_PER_SEC)))
			
			dispatch_after(startTime, dispatch_get_main_queue()) {
				var resolvedError: NSError?
				
				// Framework error
				if let error = error {
					Spine.logError(.Networking, "\(request.URL!) - \(error.localizedDescription)")
					resolvedError = NSError(domain: SpineClientErrorDomain, code: error.code, userInfo: error.userInfo)
					
					// Success
				} else if 200 ... 299 ~= statusCode {
					Spine.logInfo(.Networking, "\(statusCode): \(request.URL!)")
					
					// API Error
				} else {
					Spine.logWarning(.Networking, "\(statusCode): \(request.URL!)")
					resolvedError = NSError(domain: SpineServerErrorDomain, code: statusCode, userInfo: nil)
				}
				
				callback(statusCode: statusCode, responseData: data, networkError: resolvedError)
			}
		}
	}
	
	func respondWith(status: Int, data: NSData = NSData(), error: NSError? = nil) {
		handler = { request, payload in
			return (responseData: data, statusCode: status, error: error)
		}
	}
	
	func simulateNetworkErrorWithCode(code: Int) {
		handler = { request, payload in
			return (responseData: NSData(), statusCode: 404, error: NSError(domain: "mock", code: code, userInfo: nil))
		}
	}
}