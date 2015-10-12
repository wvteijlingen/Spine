//
//  Transformer.swift
//  Spine
//
//  Created by Ward van Teijlingen on 30-12-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation

/**
The Transformer protocol declares methods and properties that a transformer must implement.
A transformer transforms values between the serialized and deserialized form.
*/
public protocol Transformer {
	typealias SerializedType
	typealias DeserializedType
	typealias AttributeType
	
	/**
	Returns the deserialized form of the given value for the given attribute.
	
	- parameter value:     The value to deserialize.
	- parameter attribute: The attribute to which the value belongs.
	
	- returns: The deserialized form of `value`.
	*/
	func deserialize(value: SerializedType, attribute: AttributeType) -> AnyObject
	
	/**
	Returns the serialized form of the given value for the given attribute.
	
	- parameter value:     The value to serialize.
	- parameter attribute: The attribute to which the value belongs.
	
	- returns: The serialized form of `value`.
	*/
	func serialize(value: DeserializedType, attribute: AttributeType) -> AnyObject
}

/**
A transformer directory keeps a list of transformers, and chooses between these transformers
to transform values between the serialized and deserialized form.
*/
struct TransformerDirectory {
	/// Registered serializer functions.
	private var serializers: [(AnyObject, Attribute) -> AnyObject?] = []
	
	/// Registered deserializer functions.
	private var deserializers: [(AnyObject, Attribute) -> AnyObject?] = []
	
	/**
	Returns a new transformer directory configured with the build in default transformers.
	
	- returns: TransformerDirectory
	*/
	static func defaultTransformerDirectory() -> TransformerDirectory {
		var directory = TransformerDirectory()
		directory.registerTransformer(URLTransformer())
		directory.registerTransformer(DateTransformer())
		return directory
	}
	
	/**
	Registers the given transformer.
	
	- parameter transformer: The transformer to register.
	*/
	mutating func registerTransformer<T: Transformer>(transformer: T) {
		serializers.append { (value: AnyObject, attribute: Attribute) -> AnyObject? in
			if let typedAttribute = attribute as? T.AttributeType {
				if let typedValue = value as? T.DeserializedType {
					return transformer.serialize(typedValue, attribute: typedAttribute)
				}
			}
			
			return nil
		}
		
		deserializers.append { (value: AnyObject, attribute: Attribute) -> AnyObject? in
			if let typedAttribute = attribute as? T.AttributeType {
				if let typedValue = value as? T.SerializedType {
					return transformer.deserialize(typedValue, attribute: typedAttribute)
				}
			}
			
			return nil
		}
	}
	
	/**
	Returns the deserialized form of the given value for the given attribute.
	
	The actual transformer used is the first registered transformer that supports the given
	value type for the given attribute type.
	
	- parameter value:     The value to deserialize.
	- parameter attribute: The attribute to which the value belongs.
	
	- returns: The deserialized form of `value`.
	*/
	func deserialize(value: AnyObject, forAttribute attribute: Attribute) -> AnyObject {
		for deserializer in deserializers {
			if let deserialized: AnyObject = deserializer(value, attribute) {
				return deserialized
			}
		}
		
		return value
	}
	
	/**
	Returns the serialized form of the given value for the given attribute.
	
	The actual transformer used is the first registered transformer that supports the given
	value type for the given attribute type.
	
	- parameter value:     The value to serialize.
	- parameter attribute: The attribute to which the value belongs.
	
	- returns: The serialized form of `value`.
	*/
	func serialize(value: AnyObject, forAttribute attribute: Attribute) -> AnyObject {
		for serializer in serializers {
			if let serialized: AnyObject = serializer(value, attribute) {
				return serialized
			}
		}
		
		return value
	}
}


// MARK: - Built in transformers

/**
URLTransformer is a transformer that transforms between NSURL and String, and vice versa.
If a baseURL has been configured in the URLAttribute, and the given String is not an absolute URL,
it will return an absolute NSURL, relative to the baseURL.
*/
private struct URLTransformer: Transformer {
	func deserialize(value: String, attribute: URLAttribute) -> AnyObject {
		return NSURL(string: value, relativeToURL: attribute.baseURL)!
	}
	
	func serialize(value: NSURL, attribute: URLAttribute) -> AnyObject {
		return value.absoluteString
	}
}

/**
URLTransformer is a transformer that transforms between NSDate and String, and vice versa.
It uses the date format configured in the DateAttribute.
*/
private struct DateTransformer: Transformer {
	func formatter(attribute: DateAttribute) -> NSDateFormatter {
		let formatter = NSDateFormatter()
		formatter.dateFormat = attribute.format
		return formatter
	}
	
	func deserialize(value: String, attribute: DateAttribute) -> AnyObject {
		return formatter(attribute).dateFromString(value)!
	}
	
	func serialize(value: NSDate, attribute: DateAttribute) -> AnyObject {
		return formatter(attribute).stringFromDate(value)
	}
}
