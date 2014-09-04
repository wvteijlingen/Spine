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
		
		let query = Query(resourceType: "posts").findResources().flatMap { resources -> Future<[Resource]> in
			return Query(resourceType: "errors", resourceIDs: ["401"]).findResources()
			
		}.onSuccess { users in
			let count = users.count
			println("Found \(count) posts")
			
		}.onFailure { error in
			println(error)
		}
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}
}