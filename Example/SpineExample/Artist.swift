//
//  Artist.swift
//  SpineExample
//
//  Created by Ward van Teijlingen on 30-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Spine

class Artist: Resource {

	var name: String?
	var website: String?
	var albums: ResourceCollection?
	var songs: ResourceCollection?
	
	override var type: String {
		return "artists"
	}
	
	override var persistentAttributes: [String: ResourceAttribute] {
		return [
			"name": ResourceAttribute(type: .Property),
			"website": ResourceAttribute(type: .Property),
			"albums": ResourceAttribute(type: .ToMany),
			"songs": ResourceAttribute(type: .ToMany)
			]
	}
	
}
