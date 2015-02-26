//
//  FooResource.swift
//  Spine
//
//  Created by Ward van Teijlingen on 19-02-15.
//  Copyright (c) 2015 Ward van Teijlingen. All rights reserved.
//

import Foundation
import XCTest
import SwiftyJSON

class Foo: Resource {
	dynamic var stringAttribute: String?
	dynamic var integerAttribute: NSNumber?
	dynamic var floatAttribute: NSNumber?
	dynamic var booleanAttribute: NSNumber?
	dynamic var nilAttribute: AnyObject?
	dynamic var dateAttribute: NSDate?
	dynamic var toOneAttribute: Bar?
	dynamic var toManyAttribute: LinkedResourceCollection?
	
	override class var resourceType: String {
		return "foos"
	}
	
	override var attributes: [Attribute] {
		return attributesFromDictionary([
			"stringAttribute": PropertyAttribute(),
			"integerAttribute": PropertyAttribute(),
			"floatAttribute": PropertyAttribute(),
			"booleanAttribute": PropertyAttribute(),
			"nilAttribute": PropertyAttribute(),
			"dateAttribute": DateAttribute(),
			"toOneAttribute": ToOneAttribute(Bar.resourceType),
			"toManyAttribute": ToManyAttribute(Bar.resourceType)
			])
	}
}

class Bar: Resource {
	override class var resourceType: String {
		return "bars"
	}
	
	override var attributes: [Attribute] {
		return []
	}
	
	override init() {
		super.init()
	}
	
	init(id: String) {
		super.init()
		self.id = id
	}

	required init(coder: NSCoder) {
		super.init(coder: coder)
	}
}