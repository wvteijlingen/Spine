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
		
		let query = Query(resourceType: "posts", resourceIDs: ["1"])
			.include(["author", "comments", "comments.author"])
		
		query.findResources().onSuccess { resources in
			let post = resources.first! as Post
			println(post.title)
			println(post.author?.username)
		}
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}
}