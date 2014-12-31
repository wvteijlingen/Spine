//
//  Transformer.swift
//  Spine
//
//  Created by Ward van Teijlingen on 30-12-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation

public typealias TransformerFunction = (AnyObject, Attribute) -> AnyObject
public typealias Transformer = (deserialize: TransformerFunction, serialize: TransformerFunction)

// MARK: Built in transformers

let URLTransformer: Transformer = (
	deserialize: { value, attribute in
		// TODO: Make this independent from the singleton
		if let URL = NSURL(string: (value as String), relativeToURL: Spine.sharedInstance.baseURL) {
			return URL
		}
		
		assertionFailure("Could not deserialize URL: \(value)")
	},
	serialize: { value, attribute in
		return (value as NSURL).absoluteString!
	}
)

let DateTransformer: Transformer = (
	deserialize: { value, attribute in
		let formatter = NSDateFormatter()
		formatter.dateFormat = (attribute as DateAttribute).format
		
		if let date = formatter.dateFromString(value as String) {
			return date
		}
		
		assertionFailure("Could not deserialize date: \(value)")
	},
	serialize: { value, attribute in
		let formatter = NSDateFormatter()
		formatter.dateFormat = (attribute as DateAttribute).format
		return formatter.stringFromDate(value as NSDate)

	}
)

// MARK: Transformer directory

struct TransformerDirectory {
	private var transformers: [String: Transformer] = [
		URLAttribute.attributeType(): URLTransformer,
		DateAttribute.attributeType(): DateTransformer
	]
	
	mutating func registerTransformer(transformer: Transformer, forType type: Attribute.Type) {
		transformers[type.attributeType()] = transformer
	}
	
	func transformerForType(type: Attribute.Type) -> Transformer? {
		return transformers[type.attributeType()]
	}
	
	func transformerForAttribute(attribute: Attribute) -> Transformer? {
		return transformerForType(attribute.dynamicType)
	}

	subscript(type: Attribute.Type) -> Transformer? {
		return transformerForType(type)
	}
	
	func deserialize(value: AnyObject, forAttribute attribute: Attribute) -> AnyObject {
		if let transformer = self.transformerForAttribute(attribute) {
			return transformer.deserialize(value, attribute)
		} else {
			return value
		}
	}
	
	func serialize(value: AnyObject, forAttribute attribute: Attribute) -> AnyObject {
		if let transformer = self.transformerForAttribute(attribute) {
			return transformer.serialize(value, attribute)
		} else {
			return value
		}
	}
}