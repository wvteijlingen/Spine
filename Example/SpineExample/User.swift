//
//  User.swift
//  Spine
//
//  Created by Ward van Teijlingen on 21-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Spine

class User: Resource {

	var username: String?
	var comments: [Comment]?
	var posts: [Post]?
	
	override var resourceType: String {
		return "users"
	}
	
	override var persistentAttributes: [String: ResourceAttribute] {
		return [
			"username": ResourceAttribute(type: .Property),
			"comments": ResourceAttribute(type: .ToMany),
			"posts": ResourceAttribute(type: .ToMany)
		]
	}
}
