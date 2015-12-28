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
	
	override class var fields: [Field] {
		return fieldsFromDictionary([
			"stringAttribute": Attribute(),
			"integerAttribute": Attribute(),
			"floatAttribute": Attribute(),
			"booleanAttribute": Attribute(),
			"nilAttribute": Attribute(),
			"dateAttribute": DateAttribute(),
			"toOneAttribute": ToOneRelationship(Bar),
			"toManyAttribute": ToManyRelationship(Bar)
			])
	}
	
	required init() {
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

class Bar: Resource {
	override class var resourceType: String {
		return "bars"
	}
	
	override class var fields: [Field] {
		return []
	}
	
	required init() {
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