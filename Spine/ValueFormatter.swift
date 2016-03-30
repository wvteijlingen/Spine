//
//  ValueFormatter.swift
//  Spine
//
//  Created by Ward van Teijlingen on 30-12-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation

/**
The ValueFormatter protocol declares methods and properties that a value formatter must implement.
A value formatter transforms values between the serialized and deserialized form.
*/
public protocol ValueFormatter {
	associatedtype FormattedType
	associatedtype UnformattedType
	associatedtype AttributeType
	
	/**
	Returns the deserialized form of the given value for the given attribute.
	
	- parameter value:     The value to deserialize.
	- parameter attribute: The attribute to which the value belongs.
	
	- returns: The deserialized form of `value`.
	*/
	func unformat(value: FormattedType, attribute: AttributeType) -> AnyObject
	
	/**
	Returns the serialized form of the given value for the given attribute.
	
	- parameter value:     The value to serialize.
	- parameter attribute: The attribute to which the value belongs.
	
	- returns: The serialized form of `value`.
	*/
	func format(value: UnformattedType, attribute: AttributeType) -> AnyObject
}

/**
A value formatter Registry keeps a list of value formatters, and chooses between these value formatters
to transform values between the serialized and deserialized form.
*/
struct ValueFormatterRegistry {
	/// Registered serializer functions.
	private var formatters: [(AnyObject, Attribute) -> AnyObject?] = []
	
	/// Registered deserializer functions.
	private var unformatters: [(AnyObject, Attribute) -> AnyObject?] = []
	
	/**
	Returns a new value formatter directory configured with the build in default value formatters.
	
	- returns: ValueFormatterRegistry
	*/
	static func defaultRegistry() -> ValueFormatterRegistry {
		var directory = ValueFormatterRegistry()
		directory.registerFormatter(URLValueFormatter())
		directory.registerFormatter(DateValueFormatter())
		return directory
	}
	
	/**
	Registers the given value formatter.
	
	- parameter formatter: The value formatter to register.
	*/
	mutating func registerFormatter<T: ValueFormatter>(formatter: T) {
		formatters.append { (value: AnyObject, attribute: Attribute) -> AnyObject? in
			if let typedAttribute = attribute as? T.AttributeType {
				if let typedValue = value as? T.UnformattedType {
					return formatter.format(typedValue, attribute: typedAttribute)
				}
			}
			
			return nil
		}
		
		unformatters.append { (value: AnyObject, attribute: Attribute) -> AnyObject? in
			if let typedAttribute = attribute as? T.AttributeType {
				if let typedValue = value as? T.FormattedType {
					return formatter.unformat(typedValue, attribute: typedAttribute)
				}
			}
			
			return nil
		}
	}
	
	/**
	Returns the deserialized form of the given value for the given attribute.
	
	The actual value formatter used is the first registered formatter that supports the given
	value type for the given attribute type.
	
	- parameter value:     The value to deserialize.
	- parameter attribute: The attribute to which the value belongs.
	
	- returns: The deserialized form of `value`.
	*/
	func unformat(value: AnyObject, forAttribute attribute: Attribute) -> AnyObject {
		for unformatter in unformatters {
			if let unformatted: AnyObject = unformatter(value, attribute) {
				return unformatted
			}
		}
		
		return value
	}
	
	/**
	Returns the serialized form of the given value for the given attribute.
	
	The actual value formatter used is the first registered formatter that supports the given
	value type for the given attribute type.
	
	- parameter value:     The value to serialize.
	- parameter attribute: The attribute to which the value belongs.
	
	- returns: The serialized form of `value`.
	*/
	func format(value: AnyObject, forAttribute attribute: Attribute) -> AnyObject {
		for formatter in formatters {
			if let formatted: AnyObject = formatter(value, attribute) {
				return formatted
			}
		}
		
		return value
	}
}


// MARK: - Built in value formatters

/**
URLValueFormatter is a value formatter that transforms between NSURL and String, and vice versa.
If a baseURL has been configured in the URLAttribute, and the given String is not an absolute URL,
it will return an absolute NSURL, relative to the baseURL.
*/
private struct URLValueFormatter: ValueFormatter {
	func unformat(value: String, attribute: URLAttribute) -> AnyObject {
		return NSURL(string: value, relativeToURL: attribute.baseURL)!
	}
	
	func format(value: NSURL, attribute: URLAttribute) -> AnyObject {
		return value.absoluteString
	}
}

/**
DateValueFormatter is a value formatter that transforms between NSDate and String, and vice versa.
It uses the date format configured in the DateAttribute.
*/
private struct DateValueFormatter: ValueFormatter {
	func formatter(attribute: DateAttribute) -> NSDateFormatter {
		let formatter = NSDateFormatter()
		formatter.dateFormat = attribute.format
		return formatter
	}
	
	func unformat(value: String, attribute: DateAttribute) -> AnyObject {
		guard let date = formatter(attribute).dateFromString(value) else {
			Spine.logWarning(.Serializing, "Could not deserialize date string \(value) with format \(attribute.format). Deserializing to nil instead.")
			return NSNull()
		}
		return date
	}
	
	func format(value: NSDate, attribute: DateAttribute) -> AnyObject {
		return formatter(attribute).stringFromDate(value)
	}
}
