//
//  Transformer.swift
//  Spine
//
//  Created by Ward van Teijlingen on 30-12-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation

public protocol Transformer {
	typealias SerializedType
	typealias DeserializedType
	typealias AttributeType
	
	func deserialize(value: SerializedType, attribute: AttributeType) -> AnyObject
	func serialize(value: DeserializedType, attribute: AttributeType) -> AnyObject
}

struct TransformerDirectory {
	private var serializers: [(AnyObject, Attribute) -> AnyObject?] = []
	private var deserializers: [(AnyObject, Attribute) -> AnyObject?] = []
	
	static func defaultTransformerDirectory() -> TransformerDirectory {
		var directory = TransformerDirectory()
		directory.registerTransformer(URLTransformer())
		directory.registerTransformer(DateTransformer())
		return directory
	}
	
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
	
	func deserialize(value: AnyObject, forAttribute attribute: Attribute) -> AnyObject {
		for deserializer in deserializers {
			if let deserialized: AnyObject = deserializer(value, attribute) {
				return deserialized
			}
		}
		
		return value
	}
	
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

private struct URLTransformer: Transformer {
	func deserialize(value: String, attribute: URLAttribute) -> AnyObject {
		return NSURL(string: value, relativeToURL: attribute.baseURL)!
	}
	
	func serialize(value: NSURL, attribute: URLAttribute) -> AnyObject {
		return value.absoluteString!
	}
}

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
