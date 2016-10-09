//
//  CallbackHTTPClient.swift
//  Spine
//
//  Created by Ward van Teijlingen on 27-02-15.
//  Copyright (c) 2015 Ward van Teijlingen. All rights reserved.
//

import Foundation

open class CallbackHTTPClient: NetworkClient {
	typealias HandlerFunction = (_ request: URLRequest, _ payload: Data?) -> (responseData: Data?, statusCode: Int?, error: NSError?)
	
	var handler: HandlerFunction!
	var delay: TimeInterval = 0
	internal fileprivate(set) var lastRequest: URLRequest?
	let queue = DispatchQueue(label: "com.wardvanteijlingen.spine.callbackHTTPClient", attributes: [])
	
	init() {}
	
	open func request(method: String, url: URL, payload: Data?, callback: @escaping NetworkClientCallback) {
		var request = URLRequest(url: url)
		request.httpMethod = method
		
		if let payload = payload {
			request.httpBody = payload
		}
		
		lastRequest = request
		Spine.logInfo(.networking, "\(method): \(url)")
		
		// Perform the request
		queue.async {
			let (data, statusCode, error) = self.handler(request, payload)
			let startTime = DispatchTime.now() + Double(Int64(self.delay * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
			
			DispatchQueue.main.asyncAfter(deadline: startTime) {
				// Framework error
				if let error = error {
					Spine.logError(.networking, "\(request.url!) - \(error.localizedDescription)")
					
					// Success
				} else if let statusCode = statusCode , 200 ... 299 ~= statusCode {
					Spine.logInfo(.networking, "\(statusCode): \(request.url!)")
					
					// API Error
				} else {
					Spine.logWarning(.networking, "\(statusCode): \(request.url!)")
				}
				
				callback(statusCode, data, error)
			}
		}
	}
	
	func respondWith(_ status: Int, data: Data? = Data()) {
		handler = { request, payload in
			return (responseData: data, statusCode: status, error: nil)
		}
	}
	
	/**
	Simulates a network error with the given error code.
	
	- parameter code: The error code.
	
	- returns: The NSError that will be returned as the simulated network error.
	*/
	@discardableResult func simulateNetworkErrorWithCode(_ code: Int) -> NSError {
		let error = NSError(domain: "SimulatedNetworkError", code: code, userInfo: nil)
		handler = { request, payload in
			return (responseData: nil, statusCode: nil, error: error)
		}
		return error
	}
}
