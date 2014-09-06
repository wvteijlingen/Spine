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

class ViewController: UIViewController {
                            
	override func viewDidLoad() {
		super.viewDidLoad()
		
		let spine = Spine.sharedInstance
		spine.endPoint = "http://spine1.apiary-mock.com"
		
		spine.registerType(Post.self)
		spine.registerType(User.self)
		spine.registerType(Comment.self)
		
		let author = User()
		author.username = "Ward"
		
		let post = Post()
		post.title = "A title"
		post.body = "A text"
		post.author = author
		
		post.save().onSuccess { resource in
			println("Save succesful")
		}.onFailure { error in
			println("Error")
		}
		
//		author.save().flatMap { resource -> Future<Resource> in
//			post.author = author
//			return post.save()
//		}.onSuccess { resource in
//			println("Save succesful")
//		}.onFailure { error in
//			println("Error")
//		}
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}
}