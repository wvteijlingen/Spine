//
//  Networking.swift
//  Spine
//
//  Created by Ward van Teijlingen on 05-09-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation
import Alamofire

public protocol HTTPClientProtocol {
	func get(URL: String, callback:  (Int?, NSData?, NSError?) -> Void)
	func post(URL: String, json: [String: AnyObject], callback:  (Int?, NSData?, NSError?) -> Void)
	func put(URL: String, json: [String: AnyObject], callback:  (Int?, NSData?, NSError?) -> Void)
	func delete(URL: String, callback:  (Int?, NSData?, NSError?) -> Void)
}

class AlamofireClient: HTTPClientProtocol {
	
	func get(URL: String, callback:  (Int?, NSData?, NSError?) -> Void) {
		Alamofire.request(Alamofire.Method.GET, URL).response { request, response, data, error in
			callback(response?.statusCode, data as? NSData, error)
		}
	}
	
	func post(URL: String, json: [String: AnyObject], callback:  (Int?, NSData?, NSError?) -> Void) {
		Alamofire.request(Alamofire.Method.GET, URL, parameters: json, encoding: Alamofire.ParameterEncoding.JSON).response { request, response, data, error in
			callback(response?.statusCode, data as? NSData, error)
		}
	}
	
	func put(URL: String, json: [String: AnyObject], callback:  (Int?, NSData?, NSError?) -> Void) {
		Alamofire.request(Alamofire.Method.PUT, URL, parameters: json, encoding: Alamofire.ParameterEncoding.JSON).response { request, response, data, error in
			callback(response?.statusCode, data as? NSData, error)
		}
	}
	
	func delete(URL: String, callback:  (Int?, NSData?, NSError?) -> Void) {
		Alamofire.request(Alamofire.Method.DELETE, URL).response { request, response, data, error in
			callback(response?.statusCode, data as? NSData, error)
		}
	}
}