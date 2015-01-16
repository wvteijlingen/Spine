//
//  Networking.swift
//  Spine
//
//  Created by Ward van Teijlingen on 05-09-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation
import Alamofire

typealias HTTPClientCallback = (statusCode: Int, responseData: NSData?, error: NSError?) -> Void

public protocol HTTPClientHeadersProtocol {
	func setHeader(header: String, to: String)
	func removeHeader(header: String)
}

protocol HTTPClientProtocol: HTTPClientHeadersProtocol {
	var traceEnabled: Bool { get set }
	
	func get(URL: String, callback: HTTPClientCallback)
	func post(URL: String, json: [String: AnyObject], callback: HTTPClientCallback)
	func put(URL: String, json: [String: AnyObject], callback: HTTPClientCallback)
	func delete(URL: String, callback: HTTPClientCallback)
}

public class AlamofireClient: HTTPClientProtocol {
	var alamofireManager: Alamofire.Manager
	var traceEnabled = false
	
	init() {
		let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
		configuration.HTTPAdditionalHeaders = Alamofire.Manager.defaultHTTPHeaders()
		
		alamofireManager = Alamofire.Manager(configuration: configuration)
		
		setHeader("Content-Type", to: "application/vnd.api+json")
	}
	
	// MARK: Headers
	
	public func setHeader(header: String, to value: String) {
		alamofireManager.session.configuration.HTTPAdditionalHeaders?.updateValue(value, forKey: header)
	}
	
	public func removeHeader(header: String) {
		alamofireManager.session.configuration.HTTPAdditionalHeaders?.removeValueForKey(header)
	}
	
	// MARK: Basic requests
	
	func get(URL: String, callback: HTTPClientCallback) {
		trace("⬆️ GET:  " + URL)
		return self.performRequest(alamofireManager.request(.GET, URL), callback: callback)
	}
	
	func post(URL: String, json: [String: AnyObject], callback: HTTPClientCallback) {
		trace("⬆️ POST: " + URL)
		return self.performRequest(alamofireManager.request(.POST, URL, parameters: json, encoding: .JSON), callback: callback)
	}
	
	func put(URL: String, json: [String: AnyObject], callback: HTTPClientCallback) {
		trace("⬆️ PUT:  " + URL)
		return self.performRequest(alamofireManager.request(.PUT, URL, parameters: json, encoding: .JSON), callback: callback)
	}
	
	func delete(URL: String, callback: HTTPClientCallback) {
		trace("⬆️ DEL:  " + URL)
		return self.performRequest(alamofireManager.request(.DELETE, URL), callback: callback)
	}
	
	private func performRequest(request: Request, callback: HTTPClientCallback) {
		request.response { request, response, data, error in
			var resolvedError: NSError?
			
			// Framework error
			if let error = error {
				self.trace("❌ Err:  \(request.URL) - \(error.localizedDescription)")
				resolvedError = NSError(domain: SPINE_ERROR_DOMAIN, code: error.code, userInfo: error.userInfo)
			
			// Success
			} else if 200 ... 299 ~= response!.statusCode {
				self.trace("✅ \(response!.statusCode):  \(request.URL)")
			
			// API Error
			} else {
				self.trace("❌ \(response!.statusCode):  \(request.URL)")
				resolvedError = NSError(domain: SPINE_API_ERROR_DOMAIN, code: response!.statusCode, userInfo: nil)
			}
			
			callback(statusCode: response!.statusCode, responseData: data as? NSData, error: resolvedError)
		}
	}
	
	
	// MARK: Internal
	
	private func trace<T>(object: T) {
		if self.traceEnabled {
			println(object)
		}
	}
}