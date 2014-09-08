//
//  ViewController.swift
//  SpineExample
//
//  Created by Ward van Teijlingen on 30-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import UIKit
import Spine
import BrightFutures

class ViewController: UITableViewController {

	override func viewDidLoad() {
		super.viewDidLoad()
		
		self.restPack()
		
//		let spine = Spine.sharedInstance
//		spine.baseURL = "http://spine1.apiary-mock.com"
//		
//		spine.registerType(Post.self)
//		spine.registerType(User.self)
//		spine.registerType(Comment.self)
		
//		let author = User()
//		author.username = "Ward"
//
//		let post = Post()
//		post.title = "A title"
//		post.body = "A text"
//		post.author = author
//		
//		post.save().onSuccess { resource in
//			println("Save succesful")
//		}.onFailure { error in
//			println("Error")
//		}
		
//		author.save().flatMap { resource -> Future<Resource> in
//			post.author = author
//			return post.save()
//		}.onSuccess { resource in
//			println("Save succesful")
//		}.onFailure { error in
//			println("Error")
//		}
		
//		Post.findOne("1").onSuccess { resource in
//			let post = resource as Post
//			println(post.title)
//			println(post.body)
//		}.onFailure { error in
//			println(error.localizedDescription)
//		}
	}
	
	func restPack() {
		let spine = Spine.sharedInstance
		spine.baseURL = "http://restpack-serializer-sample.herokuapp.com/api/v1/"
		
		spine.registerType(Album.self)
		spine.registerType(Artist.self)
		spine.registerType(Song.self)
		
		Artist.findOne("1").onSuccess { resource in
			let artist = resource as Artist
			
			artist.findRelated("albums").onSuccess { resources in
				let album = resources.first as Album
				
				println(album.title)
			}
			
			
		}.onFailure { error in
			println(error.localizedDescription)
		}
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}
}