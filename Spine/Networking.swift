//
//  Networking.swift
//  Spine
//
//  Created by Ward van Teijlingen on 05-09-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation

typealias HTTPClientCallback = (statusCode: Int?, responseData: NSData?, error: NSError?) -> Void

public protocol HTTPClientProtocol {
	func setHeader(header: String, to: String)
	func removeHeader(header: String)
}

protocol _HTTPClientProtocol: HTTPClientProtocol {
	func request(method: String, URL: NSURL, callback: HTTPClientCallback)
	func request(method: String, URL: NSURL, payload: NSData?, callback: HTTPClientCallback)
}

public class URLSessionClient: _HTTPClientProtocol {
	let urlSession: NSURLSession
	
	init() {
		let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
		urlSession = NSURLSession(configuration: configuration)
		setHeader("Content-Type", to: "application/vnd.api+json")
	}
	
	public func setHeader(header: String, to value: String) {
		urlSession.configuration.HTTPAdditionalHeaders?.updateValue(value, forKey: header)
	}
	
	public func removeHeader(header: String) {
		urlSession.configuration.HTTPAdditionalHeaders?.removeValueForKey(header)
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
		
		Spine.logInfo(.Networking, "\(method): \(URL)")
		
		performRequest(request, callback: callback)
	}
	
	// TODO: Move error handling out of networking component
	private func performRequest(request: NSURLRequest, callback: HTTPClientCallback) {
		let task = urlSession.dataTaskWithRequest(request) { data, response, error in
			let response = (response as NSHTTPURLResponse)
			var resolvedError: NSError?
			
			// Framework error
			if let error = error {
				Spine.logError(.Networking, "\(request.URL) - \(error.localizedDescription)")
				resolvedError = NSError(domain: SPINE_ERROR_DOMAIN, code: error.code, userInfo: error.userInfo)
				
				// Success
			} else if 200 ... 299 ~= response.statusCode {
				Spine.logInfo(.Networking, "\(response.statusCode): \(request.URL)")
				
				// API Error
			} else {
				Spine.logWarning(.Networking, "\(response.statusCode): \(request.URL)")
				resolvedError = NSError(domain: SPINE_API_ERROR_DOMAIN, code: response.statusCode, userInfo: nil)
			}
			
			callback(statusCode: response.statusCode, responseData: data, error: resolvedError)
		}
		
		task.resume()
	}
}