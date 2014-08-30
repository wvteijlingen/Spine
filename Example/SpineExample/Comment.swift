//
//  Comment.swift
//  Spine
//
//  Created by Ward van Teijlingen on 21-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Spine

class Comment: Resource {
	
	var body: String?
	var author: User?
	var post: Post?
	
	override var resourceType: String {
		return "comments"
	}
	
	override var persistentAttributes: [String: ResourceAttribute] {
		return [
			"body": ResourceAttribute.Property,
			"user": ResourceAttribute.ToOne,
			"post": ResourceAttribute.ToOne,
		]
	}
}