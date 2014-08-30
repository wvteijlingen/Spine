//
//  Song.swift
//  SpineExample
//
//  Created by Ward van Teijlingen on 30-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Spine

class Song: Resource {

	var title: String?
	var year: String?
	var artist: Artist?
	var album: Album?
	
	override var resourceType: String {
		return "albums"
	}
	
	override var persistentAttributes: [String: ResourceAttribute] {
		return [
			"title": .Property,
			"year": .Property,
			"artist": .ToOne,
			"album": .ToOne
			]
	}
}
