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

protocol HTTPClientProtocol {
	var traceEnabled: Bool { get set }
	
	func get(URL: String) -> Future<(Int?, NSData?)>
	func post(URL: String, json: [String: AnyObject]) -> Future<(Int?, NSData?)>
	func put(URL: String, json: [String: AnyObject]) -> Future<(Int?, NSData?)>
	func delete(URL: String) -> Future<(Int?, NSData?)>
}

class AlamofireClient: HTTPClientProtocol {
	
	var traceEnabled = true
	
	init() {
		var additionalHeaders = Alamofire.Manager.sharedInstance.session.configuration.HTTPAdditionalHeaders!
		additionalHeaders.updateValue("application/vnd.api+json", forKey: "Content-Type")
	}
	
	func get(URL: String) -> Future<(Int?, NSData?)> {
		trace("GET:      " + URL)
		return self.performRequest(Alamofire.request(Alamofire.Method.GET, URL))
	}
	
	func post(URL: String, json: [String: AnyObject]) -> Future<(Int?, NSData?)> {
		trace("POST:     " + URL)
		return self.performRequest(Alamofire.request(Alamofire.Method.POST, URL, parameters: json, encoding: Alamofire.ParameterEncoding.JSON))
	}
	
	func put(URL: String, json: [String: AnyObject]) -> Future<(Int?, NSData?)> {
		trace("PUT:      " + URL)
		return self.performRequest(Alamofire.request(Alamofire.Method.PUT, URL, parameters: json, encoding: Alamofire.ParameterEncoding.JSON))
	}
	
	func delete(URL: String) -> Future<(Int?, NSData?)> {
		trace("DELETE:   " + URL)
		return self.performRequest(Alamofire.request(Alamofire.Method.DELETE, URL))
	}
	
	private func performRequest(request: Request) -> Future<(Int?, NSData?)> {
		let promise = Promise<(Int?, NSData?)>()
		
		request.response { request, response, data, error in
			self.trace("RESPONSE: \(request.URL)")
			
			if let error = error {
				self.trace("          └─ Network error: \(error.localizedDescription)")
				promise.error(error)
			} else {
				self.trace("          └─ HTTP status: \(response!.statusCode)")
				promise.success(response?.statusCode, data as? NSData)
			}
		}
		
		return promise.future
	}
	
	private func trace<T>(object: T) {
		if self.traceEnabled {
			println(object)
		}
	}
}