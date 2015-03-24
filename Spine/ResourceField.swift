//
//  ResourceAttribute.swift
//  Spine
//
//  Created by Ward van Teijlingen on 30-12-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation

public func fieldsFromDictionary(dictionary: [String: Field]) -> [Field] {
	return map(dictionary) { (name, field) in
		field.name = name
		return field
	}
}

/**
 *  Base field.
 *  Do not use this field type directly, instead use a specific subclass.
 */
public class Field {
	/// The name of the field as it appears in the model class.
	/// This is declared as an implicit optional to support the `fieldsFromDictionary` function,
	/// however it should *never* be nil.
	var name: String! = nil
	
	/// The name of the field as it appears in the JSON representation.
	/// This can be nil, in which case the regular name will be used.
	var serializedName: String {
		get {
			return _serializedName ?? name
		}
		set {
			_serializedName = newValue
		}
	}
	private var _serializedName: String?


	public init() {}
	
	/**
	Sets the serialized name.
	
	:param: name The serialized name to use.
	:returns: The field.
	*/
	public func serializeAs(name: String) -> Self {
		serializedName = name
		return self
	}
}

// MARK: - Built in fields

/**
 *  A basic attribute field.
 */
public class Attribute: Field { }


/**
 *  An URL attribute that maps to an NSURL property.
 *  You can optionally specify a base URL with which relative
 *  URLs will be made absolute.
 */

public class URLAttribute: Attribute {
	let baseURL: NSURL?
	
	public init(baseURL: NSURL? = nil) {
		self.baseURL = baseURL
	}
}

/**
 *  A date attribute that maps to an NSDate property.
 *  By default, it uses ISO8601 format. You can specify a custom
 *  format by passing it to the initializer.
 */
public class DateAttribute: Attribute {
	let format: String

	public init(_ format: String = "yyyy-MM-dd'T'HH:mm:ssZZZZZ") {
		self.format = format
	}
}

/**
 *  A basic relationship field.
 *  Do not use this field type directly, instead use either `ToOneRelationship` or `ToManyRelationship`.
 */
public class Relationship: Field {
	let linkedType: ResourceType
	
	public init(_ type: String) {
		linkedType = type
	}
}

/**
 *  A to-one relationship field.
 */
public class ToOneRelationship: Relationship { }

/**
 *  A to-many relationship field.
 */
public class ToManyRelationship: Relationship { }