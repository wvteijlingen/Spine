//
//  Networking.swift
//  Spine
//
//  Created by Ward van Teijlingen on 05-09-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation

public typealias NetworkClientCallback = (statusCode: Int?, data: NSData?, error: NSError?) -> Void

/**
A NetworkClient is the interface between Spine and the server. It does not impose any transport
and can be used for HTTP, websockets, and any other data transport.
*/
public protocol NetworkClient {
	/**
	Performs a network request to the given URL with the given method.
	
	- parameter method:   The method to use, expressed as a HTTP verb.
	- parameter URL:      The URL to which to make the request.
	- parameter callback: The callback to execute when the request finishes.
	*/
	func request(method: String, URL: NSURL, callback: NetworkClientCallback)
	
	/**
	Performs a network request to the given URL with the given method.
	
	- parameter method:   The method to use, expressed as a HTTP verb.
	- parameter URL:      The URL to which to make the request.
	- parameter payload:  The payload the send as part of the request.
	- parameter callback: The callback to execute when the request finishes.
	*/
	func request(method: String, URL: NSURL, payload: NSData?, callback: NetworkClientCallback)
}

extension NetworkClient {
	public func request(method: String, URL: NSURL, callback: NetworkClientCallback) {
		return request(method, URL: URL, payload: nil, callback: callback)
	}
}

/**
The HTTPClient implements the NetworkClient protocol to work over an HTTP connection.
*/
public class HTTPClient: NetworkClient {
	let urlSession: NSURLSession
	var headers: [String: String] = [:]
	
	public init() {
		let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
		configuration.HTTPAdditionalHeaders = ["Content-Type": "application/vnd.api+json"]
		urlSession = NSURLSession(configuration: configuration)
	}
	
	/**
	Sets a HTTP header for all upcoming network requests.
	
	- parameter header: The name of header to set the value for.
	- parameter value:  The value to set the header tp.
	*/
	public func setHeader(header: String, to value: String) {
		headers[header] = value
	}
	
	/**
	Removes a HTTP header for all upcoming  network requests.
	
	- parameter header: The name of header to remove.
	*/
	public func removeHeader(header: String) {
		headers.removeValueForKey(header)
	}
	
	public func buildRequest(method: String, URL: NSURL, payload: NSData?) -> NSMutableURLRequest {
		let request = NSMutableURLRequest(URL: URL)
		request.HTTPMethod = method
		
		for (key, value) in headers {
			request.setValue(value, forHTTPHeaderField: key)
		}
		
		if let payload = payload {
			request.HTTPBody = payload
		}
		
		return request
	}

	public func request(method: String, URL: NSURL, payload: NSData?, callback: NetworkClientCallback) {
		let request = buildRequest(method, URL: URL, payload: payload)
		
		Spine.logInfo(.Networking, "\(method): \(URL)")
		
		if Spine.shouldLog(.Debug, domain: .Networking) {
			if let httpBody = request.HTTPBody, stringRepresentation = NSString(data: httpBody, encoding: NSUTF8StringEncoding) {
				Spine.logDebug(.Networking, stringRepresentation)
			}
		}
		
		let task = urlSession.dataTaskWithRequest(request) { data, response, networkError in
			let response = (response as? NSHTTPURLResponse)
			
			if let error = networkError {
				// Network error
				Spine.logError(.Networking, "\(request.URL) - \(error.localizedDescription)")
				
			} else if let statusCode = response?.statusCode where 200 ... 299 ~= statusCode {
				// Success
				Spine.logInfo(.Networking, "\(statusCode): \(request.URL)")
				
			} else {
				// API Error
				Spine.logWarning(.Networking, "\(response?.statusCode): \(request.URL)")
			}
			
			if Spine.shouldLog(.Debug, domain: .Networking) {
				if let data = data, stringRepresentation = NSString(data: data, encoding: NSUTF8StringEncoding) {
					Spine.logDebug(.Networking, stringRepresentation)
				}
			}
			
			callback(statusCode: response?.statusCode, data: data, error: networkError)
		}
		
		task.resume()
	}
}