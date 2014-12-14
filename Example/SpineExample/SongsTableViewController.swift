//
//  SongsTableViewController.swift
//  SpineExample
//
//  Created by Ward van Teijlingen on 09-09-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import UIKit
import Spine
import BrightFutures

class SongsTableViewController: UITableViewController {
	
	var songs: ResourceCollection?
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		Query(resourceType: "songs").limit(5).find().onSuccess(context: Queue.main) { resourceCollection in
			self.songs = resourceCollection
			self.tableView.reloadData()
		}.onFailure(context: Queue.main) { error in
			println(error)
		}
	}
	
	func loadNextPage() {
		if self.songs?.canFetchNextPage == true {
			self.songs?.fetchNextPage().onSuccess(context: Queue.main) {
				self.tableView.reloadData()
			}
		}
	}
	
	// MARK: - Table view data source
	
	override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
		return 1
	}
	
	override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return self.songs?.resources?.count ?? 0
	}
	
	override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCellWithIdentifier("SongCell", forIndexPath: indexPath) as UITableViewCell
		
		let song = self.songs?.resources![indexPath.row] as Song
		
		cell.textLabel?.text = song.title
		
		return cell
	}
	
	override func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
		if let count = self.songs?.resources?.count {
			if indexPath.row == count - 1 {
				self.loadNextPage()
			}
		}
	}
}