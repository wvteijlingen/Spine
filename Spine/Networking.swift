//
//  Networking.swift
//  Spine
//
//  Created by Ward van Teijlingen on 05-09-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation
import Alamofire

typealias HTTPClientCallback = (statusCode: Int?, responseData: NSData?, error: NSError?) -> Void

enum HTTPClientRequestMethod {
	case GET, POST, PUT, PATCH, DELETE
}

public protocol HTTPClientProtocol {
	func setHeader(header: String, to: String)
	func removeHeader(header: String)
}

protocol _HTTPClientProtocol: HTTPClientProtocol {
	var traceEnabled: Bool { get set }
	func request(method: HTTPClientRequestMethod, URL: NSURL, callback: HTTPClientCallback)
	func request(method: HTTPClientRequestMethod, URL: NSURL, payload: [String : AnyObject]?, callback: HTTPClientCallback)
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
	
	public func setHeader(header: String, to value: String) {
		alamofireManager.session.configuration.HTTPAdditionalHeaders?.updateValue(value, forKey: header)
	}
	
	public func removeHeader(header: String) {
		alamofireManager.session.configuration.HTTPAdditionalHeaders?.removeValueForKey(header)
	}

	private func trace<T>(object: T) {
		if self.traceEnabled {
			println(object)
		}
	}
}

extension AlamofireClient: _HTTPClientProtocol {
	func request(method: HTTPClientRequestMethod, URL: NSURL, callback: HTTPClientCallback) {
		return request(method, URL: URL, payload: nil, callback: callback)
	}
	
	func request(method: HTTPClientRequestMethod, URL: NSURL, payload: [String : AnyObject]?, callback: HTTPClientCallback) {
		switch method {
		case .GET:
			trace("⬆️ GET:  \(URL)")
			return performRequest(alamofireManager.request(.GET, URL, parameters: payload, encoding: .JSON), callback: callback)
		case .POST:
			trace("⬆️ POST: \(URL)")
			return performRequest(alamofireManager.request(.POST, URL, parameters: payload, encoding: .JSON), callback: callback)
		case .PUT:
			trace("⬆️ PUT:  \(URL)")
			return performRequest(alamofireManager.request(.PUT, URL, parameters: payload, encoding: .JSON), callback: callback)
		case .PATCH:
			trace("⬆️ PAT:  \(URL)")
			return performRequest(alamofireManager.request(.PATCH, URL, parameters: payload, encoding: .JSON), callback: callback)
		case .DELETE:
			trace("⬆️ DEL:  \(URL)")
			return performRequest(alamofireManager.request(.DELETE, URL, parameters: payload, encoding: .JSON), callback: callback)
		}
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
			
			callback(statusCode: response?.statusCode, responseData: data as? NSData, error: resolvedError)
		}
	}
}