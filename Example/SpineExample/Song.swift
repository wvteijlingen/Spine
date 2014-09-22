//
//  Song.swift
//  SpineExample
//
//  Created by Ward van Teijlingen on 30-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Spine

class Song: Resource {

	dynamic var title: String?
	dynamic var artist: Artist?
	dynamic var album: Album?
	
	override var resourceType: String {
		return "songs"
	}
	
	override var persistentAttributes: [String: ResourceAttribute] {
		return [
			"title": ResourceAttribute(type: .Property),
			"artist": ResourceAttribute(type: .ToOne),
			"album": ResourceAttribute(type: .ToOne)
			]
	}
}
