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

protocol HTTPClientProtocol {
	var traceEnabled: Bool { get set }
	var credential: OAuthCredential? { get set }
	
	// MARK: Basic requests
	
	func get(URL: String) -> Future<(Int?, NSData?)>
	func post(URL: String, json: [String: AnyObject]) -> Future<(Int?, NSData?)>
	func put(URL: String, json: [String: AnyObject]) -> Future<(Int?, NSData?)>
	func delete(URL: String) -> Future<(Int?, NSData?)>

	// MARK: OAuth
	
	func authenticate(URL: String, username: String, password: String, scope: String?) -> Future<Void>
	func authenticate(URL: String, refreshToken: String) -> Future<Void>
}

class AlamofireClient: HTTPClientProtocol {
	
	var traceEnabled = true
	var credential: OAuthCredential? {
		didSet {
			var additionalHeaders = Alamofire.Manager.sharedInstance.session.configuration.HTTPAdditionalHeaders!
			
			if let credential = self.credential {
				additionalHeaders.updateValue("Bearer: \(credential.accessToken)", forKey: "Authorization")
			} else {
				additionalHeaders.removeValueForKey("Authorization")
			}
		}
	}
	
	init() {
		var additionalHeaders = Alamofire.Manager.sharedInstance.session.configuration.HTTPAdditionalHeaders!
		additionalHeaders.updateValue("application/vnd.api+json", forKey: "Content-Type")
	}
	
	// MARK: Basic requests
	
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
	
	// MARK: OAuth
	
	func authenticate(URL: String, username: String, password: String, scope: String? = nil) -> Future<Void> {
		var parameters = [
			"grant_type": OAuthCredential.TokenType.PasswordCredentialsGrant.rawValue,
			"username": username,
			"password": password,
		]
		
		if scope != nil {
			parameters["scope"] = scope!
		}
		
		return self.authenticate(URL, parameters: parameters)
	}
	
	func authenticate(URL: String, refreshToken: String) -> Future<Void> {
		let parameters = [
			"grant_type": OAuthCredential.TokenType.RefreshTokenGrant.rawValue,
			"refresh_token": refreshToken,
		]
		
		return self.authenticate(URL, parameters: parameters)
	}
	
	private func authenticate(URL: String, parameters: [String: AnyObject]) -> Future<Void> {
		// TODO: Add client_id and client_secret to parameters
		
		let promise = Promise<Void>()
		
		Alamofire.request(.POST, URL, parameters: parameters).response { request, response, data, error in
			if let error = error {
				promise.error(error)
				return
			}
			
			if let data = data as? NSData {
				let json = JSON(data: data)
				
				// OAuth error
				if let oauthError = json["error_description"].string {
					promise.error(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: oauthError]));
					return
				} else if let oauthError = json["error"].string {
					promise.error(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: oauthError]));
					return
				}
				
				// Access token
				var accessToken: String! = json["access_token"].string
				if accessToken == nil {
					promise.error(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No access token found in OAuth response."]))
					return
				}
				
				var credential = OAuthCredential(accessToken: accessToken, tokenType: .PasswordCredentialsGrant)
				
				// Refresh token
				var refreshToken: String!
				if let refresh = json["refresh_token"].string {
					refreshToken = refresh
				} else if let refresh = parameters["refresh_token"] as? String {
					refreshToken = refresh
				}
				
				// Expiration date
				var expirationDate: NSDate = NSDate.distantFuture() as NSDate
				if let expiration = json["expires_in"].double {
					expirationDate = NSDate(timeIntervalSinceNow: expiration)
				}
				
				if refreshToken != nil {
					credential.setRefreshToken(refreshToken, withExpirationDate: expirationDate)
				}
				
				self.credential = credential
				
				promise.success()
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

struct OAuthCredential: Printable {
	enum TokenType: String {
		case AuthorizationCodeGrant = "authorization_code"
		case ClientCredentialsGrant = "client_credentials"
		case PasswordCredentialsGrant = "password"
		case RefreshTokenGrant = "refresh_token"
	}
	
	var tokenType: TokenType
	var accessToken: String
	var refreshToken: String?
	var expirationDate: NSDate?
	
	init(accessToken: String, tokenType: TokenType) {
		self.accessToken = accessToken
		self.tokenType = tokenType
	}
	
	mutating func setRefreshToken(refreshToken: String, withExpirationDate expiration: NSDate) {
		self.refreshToken = refreshToken
		self.expirationDate = expiration
	}
	
	var isExpired: Bool {
		get {
			if let expirationDate = self.expirationDate {
				return expirationDate.compare(NSDate()) == .OrderedAscending
			} else {
				return false
			}
		}
	}
	
	var description: String {
		return "{accessToken: \(self.accessToken), refreshToken: \(self.refreshToken), expirationDate: \(self.expirationDate)}"
	}
}