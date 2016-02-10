//
//  CallbackHTTPClient.swift
//  Spine
//
//  Created by Ward van Teijlingen on 27-02-15.
//  Copyright (c) 2015 Ward van Teijlingen. All rights reserved.
//

import Foundation

public class CallbackHTTPClient: NetworkClient {
	typealias HandlerFunction = (request: NSURLRequest, payload: NSData?) -> (responseData: NSData?, statusCode: Int?, error: NSError?)
	
	var handler: HandlerFunction!
	var delay: NSTimeInterval = 0
	internal private(set) var lastRequest: NSURLRequest?
	let queue = dispatch_queue_create("com.wardvanteijlingen.spine.callbackHTTPClient", nil)
	
	init() {}
	
	public func request(method: String, URL: NSURL, payload: NSData?, callback: NetworkClientCallback) {
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
				// Framework error
				if let error = error {
					Spine.logError(.Networking, "\(request.URL!) - \(error.localizedDescription)")
					
					// Success
				} else if let statusCode = statusCode where 200 ... 299 ~= statusCode {
					Spine.logInfo(.Networking, "\(statusCode): \(request.URL!)")
					
					// API Error
				} else {
					Spine.logWarning(.Networking, "\(statusCode): \(request.URL!)")
				}
				
				callback(statusCode: statusCode, data: data, error: error)
			}
		}
	}
	
	func respondWith(status: Int, data: NSData? = NSData()) {
		handler = { request, payload in
			return (responseData: data, statusCode: status, error: nil)
		}
	}
	
	/**
	Simulates a network error with the given error code.
	
	- parameter code: The error code.
	
	- returns: The NSError that will be returned as the simulated network error.
	*/
	func simulateNetworkErrorWithCode(code: Int) -> NSError {
		let error = NSError(domain: "SimulatedNetworkError", code: code, userInfo: nil)
		handler = { request, payload in
			return (responseData: nil, statusCode: nil, error: error)
		}
		return error
	}
}