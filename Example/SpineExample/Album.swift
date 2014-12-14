//
//  Album.swift
//  SpineExample
//
//  Created by Ward van Teijlingen on 30-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Spine

class Album: Resource {
	
	var title: String?
	var year: NSNumber?
	var artist: LinkedResource?
	var songs: ResourceCollection?
	
	override var type: String {
		return "albums"
	}
	
	override var persistentAttributes: [String: ResourceAttribute] {
		return [
			"title": ResourceAttribute(type: .Property),
			"year": ResourceAttribute(type: .Property),
			"artist": ResourceAttribute(type: .ToOne),
			"songs": ResourceAttribute(type: .ToMany)
			]
	}
}
