//
//  ViewController.swift
//  SpineExample
//
//  Created by Ward van Teijlingen on 30-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import UIKit
import Spine

class ViewController: UIViewController {
                            
	override func viewDidLoad() {
		super.viewDidLoad()
		
		let spine = Spine(endPoint: "http://spine1.apiary-mock.com")
		
		spine.registerType(Post.self, resourceType: "posts")
		spine.registerType(User.self, resourceType: "users")
		spine.registerType(Comment.self, resourceType: "comments")
		
		//		let comment = Comment()
		//		comment.resourceID = "50"
		//
		//		let comment2 = Comment()
		//		comment2.resourceID = "100"
		//
		//		let user = User()
		//		user.resourceID = "20"
		//		user.username = "Ward"
		//
		//		let post = Post()
		//		post.resourceID = "10"
		//		post.title = "Ik ben Ward"
		//		post.body = "Gozeeeer"
		////		post.author = user
		////		post.comments = [comment, comment2]
		//
		//		spine.saveResource(post, success: {
		//			//
		//		}) { (error) in
		//			println(error)
		//		}
		
		let user = User()
		
		// Querying
		let query = Query(resourceType: "posts", resourceIDs: ["1"])
		//			.whereRelationship("author", isOrContains: user)
		//			.include(["author", "comments", "comments.author"])
		
		spine.fetchResourcesForQuery(query, success: { fetchedResources in
			let post = fetchedResources.first as Post
			println(post.title)
			println(post.creationDate)
			println(post.author?.username)
			
			}, failure: { (error: NSError) in
				println("Error: \(error)")
		})
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}


}

