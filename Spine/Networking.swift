//
//  Networking.swift
//  Spine
//
//  Created by Ward van Teijlingen on 05-09-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation
import Alamofire
import BrightFutures
import SwiftyJSON

public protocol HTTPClientHeadersProtocol {
	func setHeader(header: String, to: String)
	func removeHeader(header: String)
}

protocol HTTPClientProtocol: HTTPClientHeadersProtocol {
	var traceEnabled: Bool { get set }
	
	func get(URL: String) -> Future<(Int?, NSData?)>
	func post(URL: String, json: [String: AnyObject]) -> Future<(Int?, NSData?)>
	func put(URL: String, json: [String: AnyObject]) -> Future<(Int?, NSData?)>
	func delete(URL: String) -> Future<(Int?, NSData?)>
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
	
	func get(URL: String) -> Future<(Int?, NSData?)> {
		trace("⬆️ GET:  " + URL)
		return self.performRequest(alamofireManager.request(.GET, URL))
	}
	
	func post(URL: String, json: [String: AnyObject]) -> Future<(Int?, NSData?)> {
		trace("⬆️ POST: " + URL)
		return self.performRequest(alamofireManager.request(.POST, URL, parameters: json, encoding: .JSON))
	}
	
	func put(URL: String, json: [String: AnyObject]) -> Future<(Int?, NSData?)> {
		trace("⬆️ PUT:  " + URL)
		return self.performRequest(alamofireManager.request(.PUT, URL, parameters: json, encoding: .JSON))
	}
	
	func delete(URL: String) -> Future<(Int?, NSData?)> {
		trace("⬆️ DEL:  " + URL)
		return self.performRequest(alamofireManager.request(.DELETE, URL))
	}
	
	private func performRequest(request: Request) -> Future<(Int?, NSData?)> {
		let promise = Promise<(Int?, NSData?)>()
		
		request.response { request, response, data, error in
			if let error = error {
				self.trace("❌ Err:  \(request.URL) - \(error.localizedDescription)")
				promise.error(error)
			} else {
				self.trace("✅ \(response!.statusCode):  \(request.URL)")
				promise.success(response?.statusCode, data as? NSData)
			}
		}
		
		return promise.future
	}
	
	// MARK: Internal
	
	private func trace<T>(object: T) {
		if self.traceEnabled {
			println(object)
		}
	}
}