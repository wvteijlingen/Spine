//
//  ResourceAttribute.swift
//  Spine
//
//  Created by Ward van Teijlingen on 30-12-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation

public func fieldsFromDictionary(_ dictionary: [String: Field]) -> [Field] {
	return dictionary.map { (name, field) in
		field.name = name
		return field
	}
}

/**
 *  Base field.
 *  Do not use this field type directly, instead use a specific subclass.
 */
open class Field {
	/// The name of the field as it appears in the model class.
	/// This is declared as an implicit optional to support the `fieldsFromDictionary` function,
	/// however it should *never* be nil.
	open internal(set) var name: String! = nil
	
	/// The name of the field that will be used for formatting to the JSON key.
	/// This can be nil, in which case the regular name will be used.
	open internal(set) var serializedName: String {
		get {
			return _serializedName ?? name
		}
		set {
			_serializedName = newValue
		}
	}
	fileprivate var _serializedName: String?
	
	var isReadOnly: Bool = false

	fileprivate init() {}
	
	/**
	Sets the serialized name.
	
	- parameter name: The serialized name to use.
	- returns: The field.
	*/
	open func serializeAs(_ name: String) -> Self {
		serializedName = name
		return self
	}
	
	open func readOnly() -> Self {
		isReadOnly = true
		return self
	}
}

// MARK: - Built in fields

/**
 *  A basic attribute field.
 */
open class Attribute: Field {
	override public init() {}
}

/**
 *  An URL attribute that maps to an NSURL property.
 *  You can optionally specify a base URL to which relative
 *  URLs will be made absolute.
 */
open class URLAttribute: Attribute {
	let baseURL: URL?
	
	public init(baseURL: URL? = nil) {
		self.baseURL = baseURL
	}
}

/**
 *  A date attribute that maps to an NSDate property.
 *  By default, it uses ISO8601 format `yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ`.
 *  You can specify a custom format by passing it to the initializer.
 */
open class DateAttribute: Attribute {
	let format: String

	public init(format: String = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ") {
		self.format = format
	}
}

/**
 *  A basic relationship field.
 *  Do not use this field type directly, instead use either `ToOneRelationship` or `ToManyRelationship`.
 */
open class Relationship: Field {
	let linkedType: Resource.Type
	
	public init(_ type: Resource.Type) {
		linkedType = type
	}
}

/**
 *  A to-one relationship field.
 */
open class ToOneRelationship: Relationship { }

/**
 *  A to-many relationship field.
 */
open class ToManyRelationship: Relationship { }
