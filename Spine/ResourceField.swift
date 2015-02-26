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
 *  Base field
 */
public class Field {
	var name: String!
	
	private var _serializedName: String?
	var serializedName: String {
		get {
			return _serializedName ?? name
		}
		set {
			_serializedName = newValue
		}
	}

	public init() {}
	
	public func serializeAs(name: String) -> Self {
		serializedName = name
		return self
	}
}

// MARK: - Built in fields

public class Attribute: Field { }

public class URLAttribute: Attribute {
	let baseURL: NSURL?
	
	public init(baseURL: NSURL? = nil) {
		self.baseURL = baseURL
	}
}

public class DateAttribute: Attribute {
	let format: String

	public init(_ format: String = "yyyy-MM-dd'T'HH:mm:ssZZZZZ") {
		self.format = format
	}
}

public class Relationship: Field {
	let linkedType: String
	
	public init(_ type: String) {
		linkedType = type
	}
}

public class ToOneRelationship: Relationship { }

public class ToManyRelationship: Relationship { }