//
//  Formatting.swift
//  Spine
//
//  Created by Ward van Teijlingen on 27-12-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation

class Formatter {
	
	func deserialize(value: AnyObject, ofType type: ResourceAttribute.AttributeType) -> AnyObject {
		switch type {
		case .ISO8601Date:
			return self.deserializeISO8601Date(value as String)
		case .URL:
			return self.deserializeURL(value as String)
		default:
			return value
		}
	}
	
	func serialize(value: AnyObject, ofType type: ResourceAttribute.AttributeType) -> AnyObject {
		switch type {
		case .ISO8601Date:
			return self.serializeISO8601Date(value as NSDate)
		default:
			return value
		}
	}
	
	// MARK: Date
	
	private func serializeISO8601Date(date: NSDate) -> String {
		let formatter = NSDateFormatter()
		formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
		return formatter.stringFromDate(date)
	}
	
	private func deserializeISO8601Date(value: String) -> NSDate {
		let formatter = NSDateFormatter()
		formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
		
		if let date = formatter.dateFromString(value) {
			return date
		}
		
		assertionFailure("Could not deserialize ISO8601 date: \(value)")
	}
	
	// MARK: URL
	
	private func serializeURL(URL: NSURL) -> String {
		return URL.absoluteString!
	}
	
	private func deserializeURL(value: String) -> NSURL {
		if let URL = NSURL(string: value) {
			return URL
		}
		
		assertionFailure("Could not deserialize URL: \(value)")
	}
}