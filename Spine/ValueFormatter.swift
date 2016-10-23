//
//  ValueFormatter.swift
//  Spine
//
//  Created by Ward van Teijlingen on 30-12-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation



/// The ValueFormatter protocol declares methods and properties that a value formatter must implement.
/// A value formatter transforms values between the serialized and deserialized form.
public protocol ValueFormatter {
	/// The type as it appears in serialized form (JSON).
	associatedtype FormattedType
	
	/// The type as it appears in deserialized form (Swift).
	associatedtype UnformattedType
	
	/// The attribute type for which this formatter formats values.
	associatedtype AttributeType
	
	
	/// Returns the deserialized form of the given value for the given attribute.
	///
	/// - parameter value:        The value to deserialize.
	/// - parameter forAttribute: The attribute to which the value belongs.
	///
	/// - returns: The deserialized form of `value`.
	func unformatValue(_ value: FormattedType, forAttribute: AttributeType) -> UnformattedType
	
	/// Returns the serialized form of the given value for the given attribute.
	///
	/// - parameter value:        The value to serialize.
	/// - parameter forAttribute: The attribute to which the value belongs.
	///
	/// - returns: The serialized form of `value`.
	func formatValue(_ value: UnformattedType, forAttribute: AttributeType) -> FormattedType
}

/// A value formatter Registry keeps a list of value formatters, and chooses between these value formatters
/// to transform values between the serialized and deserialized form.
struct ValueFormatterRegistry {
	/// Registered serializer functions.
	fileprivate var formatters: [(Any, Attribute) -> Any?] = []
	
	/// Registered deserializer functions.
	fileprivate var unformatters: [(Any, Attribute) -> Any?] = []
	
	/// Returns a new value formatter directory configured with the built in default value formatters.
	///
	/// - returns: ValueFormatterRegistry
	static func defaultRegistry() -> ValueFormatterRegistry {
		var directory = ValueFormatterRegistry()
		directory.registerFormatter(URLValueFormatter())
		directory.registerFormatter(DateValueFormatter())
		directory.registerFormatter(BooleanValueFormatter())
		return directory
	}

	/// Registers the given value formatter.
	///
	/// - parameter formatter: The value formatter to register.
	mutating func registerFormatter<T: ValueFormatter>(_ formatter: T) {
		formatters.append { (value: Any, attribute: Attribute) -> Any? in
			if let typedAttribute = attribute as? T.AttributeType {
				if let typedValue = value as? T.UnformattedType {
					return formatter.formatValue(typedValue, forAttribute: typedAttribute)
				}
			}
			
			return nil
		}
		
		unformatters.append { (value: Any, attribute: Attribute) -> Any? in
			if let typedAttribute = attribute as? T.AttributeType {
				if let typedValue = value as? T.FormattedType {
					return formatter.unformatValue(typedValue, forAttribute: typedAttribute)
				}
			}
			
			return nil
		}
	}
	
	/// Returns the deserialized form of the given value for the given attribute.
	///
	/// The actual value formatter used is the first registered formatter that supports the given
	/// value type for the given attribute type.
	///
	/// - parameter value:     The value to deserialize.
	/// - parameter attribute: The attribute to which the value belongs.
	///
	/// - returns: The deserialized form of `value`.
	func unformatValue(_ value: Any, forAttribute attribute: Attribute) -> Any {
		for unformatter in unformatters {
			if let unformatted = unformatter(value, attribute) {
				return unformatted
			}
		}
		
		return value
	}
	
	/// Returns the serialized form of the given value for the given attribute.
	///
	/// The actual value formatter used is the first registered formatter that supports the given
	/// value type for the given attribute type. If no suitable value formatter is found,
	/// the value is returned as is.
	///
	/// - parameter value:        The value to serialize.
	/// - parameter forAttribute: The attribute to which the value belongs.
	///
	/// - returns: The serialized form of `value`.
	func formatValue(_ value: Any, forAttribute attribute: Attribute) -> Any {
		for formatter in formatters {
			if let formatted = formatter(value, attribute) {
				return formatted
			}
		}
		
		Spine.logWarning(.serializing, "No value formatter found for attribute \(attribute).")
		return value
	}
}


// MARK: - Built in value formatters

/// URLValueFormatter is a value formatter that transforms between URL and String, and vice versa.
/// If a baseURL has been configured in the URLAttribute, and the given String is not an absolute URL,
/// it will return an absolute URL, relative to the baseURL.
private struct URLValueFormatter: ValueFormatter {
	func unformatValue(_ value: String, forAttribute attribute: URLAttribute) -> URL {
		return URL(string: value, relativeTo: attribute.baseURL as URL?)!
	}
	
	func formatValue(_ value: URL, forAttribute attribute: URLAttribute) -> String {
		return value.absoluteString
	}
}

/// DateValueFormatter is a value formatter that transforms between NSDate and String, and vice versa.
/// It uses the date format configured in the DateAttribute.
private struct DateValueFormatter: ValueFormatter {
	func formatter(_ attribute: DateAttribute) -> DateFormatter {
		let formatter = DateFormatter()
		formatter.dateFormat = attribute.format
		return formatter
	}
	
	func unformatValue(_ value: String, forAttribute attribute: DateAttribute) -> Date {
		guard let date = formatter(attribute).date(from: value) else {
			Spine.logWarning(.serializing, "Could not deserialize date string \(value) with format \(attribute.format).")
			return Date(timeIntervalSince1970: 0)
		}
		return date
	}
	
	func formatValue(_ value: Date, forAttribute attribute: DateAttribute) -> String {
		return formatter(attribute).string(from: value)
	}
}

/// BooleanValueformatter is a value formatter that formats NSNumber to Bool, and vice versa.
private struct BooleanValueFormatter: ValueFormatter {
	func unformatValue(_ value: Bool, forAttribute: BooleanAttribute) -> NSNumber {
		return NSNumber(booleanLiteral: value)
	}
	
	func formatValue(_ value: NSNumber, forAttribute: BooleanAttribute) -> Bool {
		return value.boolValue
	}
}
