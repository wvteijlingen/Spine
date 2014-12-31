//
//  ResourceAttribute.swift
//  Spine
//
//  Created by Ward van Teijlingen on 30-12-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation


func isRelationship(attribute: Attribute) -> Bool {
	return (attribute is ToOneAttribute) || (attribute is ToManyAttribute)
}


/**
*  Base attribute
*/
public class Attribute {
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
	
	class func attributeType() -> String {
		return "_unspecified"
	}
	
	init() { }
	
	public func serializeAs(name: String) -> Self{
		serializedName = name
		return self
	}
}

// MARK: - Built in attributes

public class PropertyAttribute: Attribute {
	override class func attributeType() -> String {
		return "property"
	}
	
	public override init() { }
}

public class URLAttribute: Attribute {
	override class func attributeType() -> String {
		return "url"
	}
	
	public override init() { }
}

public class DateAttribute: Attribute {
	let format: String
	
	override class func attributeType() -> String {
		return "date"
	}
	
	public init(_ format: String = "yyyy-MM-dd'T'HH:mm:ssZZZZZ") {
		self.format = format
	}
}

public class ToOneAttribute: Attribute {
	let linkedType: String
	
	public init(_ type: String) {
		linkedType = type
	}
	
	override class func attributeType() -> String {
		return "toOne"
	}
}

public class ToManyAttribute: Attribute {
	let linkedType: String
	
	public init(_ type: String) {
		linkedType = type
	}
	
	override class func attributeType() -> String {
		return "toMany"
	}
} 