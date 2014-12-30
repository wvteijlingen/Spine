//
//  ResourceAttribute.swift
//  Spine
//
//  Created by Ward van Teijlingen on 30-12-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation

public protocol AttributeType { }

public class Attribute {
	var type: AttributeType
	
	var name: String
	
	private var _serializedName: String?
	var serializedName: String {
		get {
			return _serializedName ?? name
		}
		set {
			_serializedName = newValue
		}
	}
	
	init(_ name: String, type: AttributeType, serializedName: String? = nil) {
		self.name = name
		self.type = type
		
		if serializedName != nil {
			self.serializedName = serializedName!
		}
	}
	
	public func serializeAs(key: String) -> Attribute {
		serializedName = key
		return self
	}
}


// MARK: - Property

public struct PropertyType: AttributeType { }

extension Attribute {
	public class func property(name: String) -> Attribute {
		return Attribute(name, type: PropertyType())
	}
}


// MARK: - ToOne

public struct ToOneType: AttributeType {
	var linkedType: String
}

extension Attribute {
	public class func toOne(name: String, linkedType: String) -> Attribute {
		return Attribute(name, type: ToOneType(linkedType: linkedType))
	}
}


// MARK: - ToMany

public struct ToManyType: AttributeType {
	var linkedType: String
}

extension Attribute {
	public class func toMany(name: String, linkedType: String) -> Attribute {
		return Attribute(name, type: ToManyType(linkedType: linkedType))
	}
}


// MARK: - Date

public struct DateType: AttributeType {
	var format: String = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
}

extension Attribute {
	public class func date(name: String, format: String = "yyyy-MM-dd'T'HH:mm:ssZZZZZ") -> Attribute {
		return Attribute(name, type: DateType(format: format))
	}
}


// MARK: - URL

public struct URLType: AttributeType {

}

extension Attribute {
	public class func url(name: String) -> Attribute {
		return Attribute(name, type: URLType())
	}
}