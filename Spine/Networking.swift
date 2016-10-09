//
//  Networking.swift
//  Spine
//
//  Created by Ward van Teijlingen on 05-09-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation

public typealias NetworkClientCallback = (_ statusCode: Int?, _ data: Data?, _ error: NSError?) -> Void

/**
A NetworkClient is the interface between Spine and the server. It does not impose any transport
and can be used for HTTP, websockets, and any other data transport.
*/
public protocol NetworkClient {
	/**
	Performs a network request to the given URL with the given method.
	
	- parameter method:   The method to use, expressed as a HTTP verb.
	- parameter url:      The URL to which to make the request.
	- parameter callback: The callback to execute when the request finishes.
	*/
	func request(method: String, url: URL, callback: @escaping NetworkClientCallback)
	
	/**
	Performs a network request to the given URL with the given method.
	
	- parameter method:   The method to use, expressed as a HTTP verb.
	- parameter url:      The URL to which to make the request.
	- parameter payload:  The payload the send as part of the request.
	- parameter callback: The callback to execute when the request finishes.
	*/
	func request(method: String, url: URL, payload: Data?, callback: @escaping NetworkClientCallback)
}

extension NetworkClient {
	public func request(method: String, url: URL, callback: @escaping NetworkClientCallback) {
		return request(method: method, url: url, payload: nil, callback: callback)
	}
}

/**
The HTTPClient implements the NetworkClient protocol to work over an HTTP connection.
*/
open class HTTPClient: NetworkClient {
	open var delegate: HTTPClientDelegate?
	let urlSession: URLSession
	var headers: [String: String] = ["Content-Type": "application/vnd.api+json"]
	
	/**
	Initializes an HTTPClient with the given URLSession.
	
	- parameter session: The URLSession to use.
	*/
	public init(session: URLSession) {
		urlSession = session
	}
	
	/**
	Initializes a HTTPClient with an URLSession that uses the
	`URLSessionConfiguration.defaultSessionConfiguration()` configuration.
	*/
	public convenience init() {
		let sessionConfiguration = URLSessionConfiguration.default
		self.init(session: URLSession(configuration: sessionConfiguration))
	}
	
	/**
	Sets a HTTP header for all upcoming network requests.
	
	- parameter header: The name of header to set the value for.
	- parameter value:  The value to set the header tp.
	*/
	open func setHeader(_ header: String, to value: String) {
		headers[header] = value
	}
	
	/**
	Removes a HTTP header for all upcoming  network requests.
	
	- parameter header: The name of header to remove.
	*/
	open func removeHeader(_ header: String) {
		headers.removeValue(forKey: header)
	}
	
	open func buildRequest(_ method: String, url: URL, payload: Data?) -> URLRequest {
		var request = URLRequest(url: url)
		request.httpMethod = method
		
		for (key, value) in headers {
			request.setValue(value, forHTTPHeaderField: key)
		}
		
		if let payload = payload {
			request.httpBody = payload
		}
		
		return request
	}

	open func request(method: String, url: URL, payload: Data?, callback: @escaping NetworkClientCallback) {
		delegate?.httpClient(self, willPerformRequestWithMethod: method, url: url, payload: payload)
		
		let request = buildRequest(method, url: url, payload: payload)
		
		Spine.logInfo(.networking, "\(method): \(url)")
		
		if Spine.shouldLog(.debug, domain: .networking) {
			if let httpBody = request.httpBody, let stringRepresentation = NSString(data: httpBody, encoding: String.Encoding.utf8.rawValue) {
				Spine.logDebug(.networking, stringRepresentation)
			}
		}
		
		let task = urlSession.dataTask(with: request, completionHandler: { data, response, networkError in
			let response = (response as? HTTPURLResponse)
			let success: Bool
			
			if let error = networkError {
				// Network error
				Spine.logError(.networking, "\(request.url!) - \(error.localizedDescription)")
				success = false
				
			} else if let statusCode = response?.statusCode , 200 ... 299 ~= statusCode {
				// Success
				Spine.logInfo(.networking, "\(statusCode): \(request.url!) – (\(data!.count) bytes)")
				success = true
				
			} else {
				// API Error
				Spine.logWarning(.networking, "\(response!.statusCode): \(request.url!) – (\(data!.count) bytes)")
				success = false
			}
			
			if Spine.shouldLog(.debug, domain: .networking) {
				if let data = data, let stringRepresentation = NSString(data: data, encoding: String.Encoding.utf8.rawValue) {
					Spine.logDebug(.networking, stringRepresentation)
				}
			}
			
			self.delegate?.httpClient(self, didPerformRequestWithMethod: method, url: url, success: success)
			callback(response?.statusCode, data, networkError as NSError?)
		}) 
		
		task.resume()
	}
}

public protocol HTTPClientDelegate {
 /**
	Called before the HTTPClient will perform an HTTP request.
	
	- parameter client:  The client that will perform the request.
	- parameter method:  The HTTP method of the request.
	- parameter url:     The URL of the request.
	- parameter payload: The optional payload of the request.
	*/
	func httpClient(_ client: HTTPClient, willPerformRequestWithMethod method: String, url: URL, payload: Data?)
	
 /**
	Called after the HTTPClient performed an HTTP request. This method is called after the request finished,
	but before the request has been processed by the NetworkClientCallback that was initially passed.
	
	- parameter client:  The client that performed the request.
	- parameter method:  The HTTP method of the request.
	- parameter url:     The URL of the request.
	- parameter success: Whether the reques was successful. Network and error responses are consided unsuccessful.
	*/
	func httpClient(_ client: HTTPClient, didPerformRequestWithMethod method: String, url: URL, success: Bool)
}
