//
//  Post.swift
//  Spine
//
//  Created by Ward van Teijlingen on 21-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import UIKit
import Spine

class Post: Resource {
	
	var title: String?
	var body: String?
	var creationDate: NSDate?
	var author: User?
	var comments: [Comment]?
	
	override var resourceType: String {
		return "posts"
	}
	
	override var persistentAttributes: [String: ResourceAttribute] {
		return [
			"title": ResourceAttribute.Property,
			"body": ResourceAttribute.Property,
			"author": ResourceAttribute.ToOne,
			"comments": ResourceAttribute.ToMany
		]
	}
}
