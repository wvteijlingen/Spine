//
//  Networking.swift
//  Spine
//
//  Created by Ward van Teijlingen on 05-09-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation

/// Callback used by the _HTTPClientProtocol
typealias HTTPClientCallback = (statusCode: Int?, responseData: NSData?, networkError: NSError?) -> Void

/**
The HTTPClientProtocol declares methods and properties that a HTTP client must implement.
*/
public protocol HTTPClientProtocol {
	/// Sets a HTTP header for all upcoming network requests.
	func setHeader(header: String, to: String)
	
	/// Removes a HTTP header for all upcoming  network requests.
	func removeHeader(header: String)
}

/**
The _HTTPClientProtocol declares methods and properties that a HTTP client must implement.
*/
protocol _HTTPClientProtocol: HTTPClientProtocol {
	/// Performs a network request to the given URL with the given HTTP method.
	func request(method: String, URL: NSURL, callback: HTTPClientCallback)
	
	/// Performs a network request to the given URL with the given HTTP method and request body data.
	func request(method: String, URL: NSURL, payload: NSData?, callback: HTTPClientCallback)
}

/**
The built in HTTP client that uses an NSURLSession for networking.
*/
public class URLSessionClient: _HTTPClientProtocol {
	let urlSession: NSURLSession
	var headers: [String: String] = [:]
	
	init() {
		let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
		configuration.HTTPAdditionalHeaders = ["Content-Type": "application/vnd.api+json"]
		urlSession = NSURLSession(configuration: configuration)
	}
	
	public func setHeader(header: String, to value: String) {
		headers[header] = value
	}
	
	public func removeHeader(header: String) {
		headers.removeValueForKey(header)
	}
	
	func request(method: String, URL: NSURL, callback: HTTPClientCallback) {
		return request(method, URL: URL, payload: nil, callback: callback)
	}
	
	func request(method: String, URL: NSURL, payload: NSData?, callback: HTTPClientCallback) {
		let request = NSMutableURLRequest(URL: URL)
		request.HTTPMethod = method
		
		for (key, value) in headers {
			request.setValue(value, forHTTPHeaderField: key)
		}
		
		Spine.logInfo(.Networking, "\(method): \(URL)")
		
		if let payload = payload {
			request.HTTPBody = payload
			
			if Spine.shouldLog(.Debug, domain: .Networking) {
				if let stringRepresentation = NSString(data: payload, encoding: NSUTF8StringEncoding) {
					Spine.logDebug(.Networking, stringRepresentation)
				}
			}
		}
		
		performRequest(request, callback: callback)
	}
	
	private func performRequest(request: NSURLRequest, callback: HTTPClientCallback) {
		let task = urlSession.dataTaskWithRequest(request) { data, response, error in
			let response = (response as? NSHTTPURLResponse)
			
			// Network error
			if let error = error {
				Spine.logError(.Networking, "\(request.URL) - \(error.localizedDescription)")
				
			// Success
			} else if let statusCode = response?.statusCode where 200 ... 299 ~= statusCode {
				Spine.logInfo(.Networking, "\(statusCode): \(request.URL)")
				
			// API Error
			} else {
				Spine.logWarning(.Networking, "\(response?.statusCode): \(request.URL)")
			}
			
			if Spine.shouldLog(.Debug, domain: .Networking) {
				if let stringRepresentation = NSString(data: data, encoding: NSUTF8StringEncoding) {
					Spine.logDebug(.Networking, stringRepresentation)
				}
			}
			
			callback(statusCode: response?.statusCode, responseData: data, networkError: error)
		}
		
		task.resume()
	}
}