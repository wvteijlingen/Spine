//
//  Formatting.swift
//  Spine
//
//  Created by Ward van Teijlingen on 27-12-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation

class Formatter {
	
	func deserialize(value: AnyObject, ofType type: AttributeType) -> AnyObject {
		switch type {
		case let date as DateType:
			return self.deserializeDate(value as String, format: date.format)
		case let URL as URLType:
			return self.deserializeURL(value as String)
		default:
			return value
		}
	}
	
	func serialize(value: AnyObject, ofType type: AttributeType) -> AnyObject {
		switch type {
		case let date as DateType:
			return self.serializeDate(value as NSDate, format: date.format)
		default:
			return value
		}
	}
	
	// MARK: Date
	
	private func serializeDate(date: NSDate, format: String) -> String {
		let formatter = NSDateFormatter()
		formatter.dateFormat = format
		return formatter.stringFromDate(date)
	}
	
	private func deserializeDate(value: String, format: String) -> NSDate {
		let formatter = NSDateFormatter()
		formatter.dateFormat = format
		
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