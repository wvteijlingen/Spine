//
//  Networking.swift
//  Spine
//
//  Created by Ward van Teijlingen on 05-09-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation
import Alamofire

class AlamofireClient {
	
	var traceEnabled = true
	
	init() {
		var additionalHeaders = Alamofire.Manager.sharedInstance.session.configuration.HTTPAdditionalHeaders!
		additionalHeaders.updateValue("application/vnd.api+json", forKey: "Content-Type")
	}
	
	func get(URL: String, callback:  (Int?, NSData?, NSError?) -> Void) {
		trace("GET:      " + URL)
		self.performRequest(Alamofire.request(Alamofire.Method.GET, URL), callback: callback)
	}
	
	func post(URL: String, json: [String: AnyObject], callback:  (Int?, NSData?, NSError?) -> Void) {
		trace("POST:     " + URL)
		self.performRequest(Alamofire.request(Alamofire.Method.POST, URL, parameters: json, encoding: Alamofire.ParameterEncoding.JSON), callback: callback)
	}
	
	func put(URL: String, json: [String: AnyObject], callback:  (Int?, NSData?, NSError?) -> Void) {
		trace("PUT:      " + URL)
		self.performRequest(Alamofire.request(Alamofire.Method.PUT, URL, parameters: json, encoding: Alamofire.ParameterEncoding.JSON), callback: callback)
	}
	
	func delete(URL: String, callback: (Int?, NSData?, NSError?) -> Void) {
		trace("DELETE:   " + URL)
		self.performRequest(Alamofire.request(Alamofire.Method.DELETE, URL), callback: callback)
	}
	
	private func performRequest(request: Request, callback: (Int?, NSData?, NSError?) -> Void) {
		request.response { request, response, data, error in
			self.trace("RESPONSE: \(request.URL)")
			
			if let error = error {
				self.trace("          └─ Network error: \(error.localizedDescription)")
			} else {
				self.trace("          └─ HTTP status: \(response!.statusCode)")
			}
			
			callback(response?.statusCode, data as? NSData, error)
		}
	}
	
	private func trace<T>(object: T) {
		if self.traceEnabled {
			println(object)
		}
	}
}