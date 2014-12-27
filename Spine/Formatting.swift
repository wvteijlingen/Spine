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
		case .Date:
			return self.deserializeDate(value as String)
		default:
			return value
		}
	}
	
	func serialize(value: AnyObject, ofType type: ResourceAttribute.AttributeType) -> AnyObject {
		switch type {
		case .Date:
			return self.serializeDate(value as NSDate)
		default:
			return value
		}
	}
	
	// MARK: Date
	
	private lazy var dateFormatter: NSDateFormatter = {
		let formatter = NSDateFormatter()
		formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
		return formatter
		}()
	
	private func serializeDate(date: NSDate) -> String {
		return self.dateFormatter.stringFromDate(date)
	}
	
	private func deserializeDate(value: String) -> NSDate {
		if let date = self.dateFormatter.dateFromString(value) {
			return date
		}
		
		return NSDate()
	}
}