//
//  Utilities.swift
//  Spine
//
//  Created by Ward van Teijlingen on 27-12-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation

func isRelationship(attribute: Attribute) -> Bool {
	return (attribute.type is ToOneType) || (attribute.type is ToManyType)
}

extension String {
	func interpolate(callback: (key: String) -> String?) -> String {
		var interpolatedString = ""
		let scanner = NSScanner(string: self)
		
		while(scanner.atEnd == false) {
			var scannedPart: NSString?
			var scannedKey: NSString?
			
			scanner.scanUpToString("{", intoString: &scannedPart)
			scanner.scanString("{", intoString: nil)
			scanner.scanUpToString("}", intoString: &scannedKey)
			
			if let part = scannedPart {
				interpolatedString = interpolatedString + part
			}
			
			if let key = scannedKey {
				if let value = callback(key: key) {
					interpolatedString = interpolatedString + value
				}
				scanner.scanString("}", intoString: nil)
			}
		}
		
		return interpolatedString
	}
	
	func interpolate(values: NSObject, rootKeyPath: String? = nil) -> String? {
		let fallbackPrefix = "links"
		let fallbackPostfix = "id"
		
		func formatValue(value: AnyObject?) -> String? {
			if value == nil {
				return nil
			}
			
			switch value {
			case let stringValue as String:
				return stringValue
			case let intValue as Int:
				return "\(intValue)"
			case let doubleValue as Double:
				return "\(doubleValue)"
			case let stringArrayValue as [String]:
				return ",".join(stringArrayValue)
			default:
				return nil
			}
		}
		
		return self.interpolate { key in
			var keyPath = key
			
			if let prefix = rootKeyPath {
				if keyPath.hasPrefix(prefix) {
					let stringToRemove = prefix + "."
					keyPath = keyPath.substringFromIndex(stringToRemove.endIndex)
				}
			}
			
			if let value1 = formatValue(values.valueForKeyPath(keyPath)) {
				return value1
			} else if let value2 = formatValue(values.valueForKeyPath("\(keyPath).\(fallbackPostfix)")) {
				return value2
			} else if let value3 = formatValue(values.valueForKeyPath("\(fallbackPrefix).\(keyPath)")) {
				return value3
			}
			
			return nil
		}
	}
}