//
//  KeyFormatter.swift
//  Spine
//
//  Created by Ward van Teijlingen on 29/12/15.
//  Copyright © 2015 Ward van Teijlingen. All rights reserved.
//

import Foundation

/**
The KeyFormatter protocol declares methods and properties that a key formatter must implement.
A key formatter transforms field names as they appear in Resources to keys as they appear in a JSONAPI document.
*/
public protocol KeyFormatter {
	func format(field: Field) -> String
}

/**
AsIsKeyFormatter does not format anything, i.e. it returns the field name as it. Use this if your field names correspond to
keys in a JSONAPI document one to one.
*/
public struct AsIsKeyFormatter: KeyFormatter {
	public func format(field: Field) -> String {
		return field.serializedName
	}
	
	public init() { }
}

/**
DasherizedKeyFormatter formats field names as dasherized keys. Eg. someFieldName -> some-field-name.
*/
public struct DasherizedKeyFormatter: KeyFormatter {
	let regex: NSRegularExpression
	
	public func format(field: Field) -> String {
		let name = field.serializedName
		let dashed = regex.stringByReplacingMatchesInString(name, options: NSMatchingOptions(), range: NSMakeRange(0, name.characters.count), withTemplate: "-$1$2")
		return dashed.lowercaseString.stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: "-"))
	}
	
	public init() {
		regex = try! NSRegularExpression(pattern: "(?<=[a-z])([A-Z])|([A-Z])(?=[a-z])", options: NSRegularExpressionOptions())
	}
}

/*
UnderscoredKeyFormatter formats field names as underscored keys. Eg. someFieldName -> some_field_name.
*/
public struct UnderscoredKeyFormatter: KeyFormatter {
	let regex: NSRegularExpression
	
	public func format(field: Field) -> String {
		let name = field.serializedName
		let underscored = regex.stringByReplacingMatchesInString(name, options: NSMatchingOptions(), range: NSMakeRange(0, name.characters.count), withTemplate: "_$1$2")
		return underscored.lowercaseString.stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: "_"))
	}
	
	public init() {
		regex = try! NSRegularExpression(pattern: "(?<=[a-z])([A-Z])|([A-Z])(?=[a-z])", options: NSRegularExpressionOptions())
	}
}
