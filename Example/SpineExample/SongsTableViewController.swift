//
//  SongsTableViewController.swift
//  SpineExample
//
//  Created by Ward van Teijlingen on 09-09-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import UIKit
import Spine

class SongsTableViewController: UITableViewController {
	
	var paginator: Paginator!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		let query = Query(resourceType: "songs").limit(5)
		
		self.paginator = Paginator(query: query)
		
		self.loadNextPage()
	}
	
	func loadNextPage() {
		if self.paginator.canFetchNextPage {
			self.paginator.fetchNextPage().onSuccess { resources, meta in
				self.tableView.reloadData()
			}
		}
	}
	
	// MARK: - Table view data source
	
	override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
		return 1
	}
	
	override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return self.paginator.fetchedResources.count
	}
	
	override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCellWithIdentifier("SongCell", forIndexPath: indexPath) as UITableViewCell
		
		let song = self.paginator.fetchedResources[indexPath.row] as Song
		
		cell.textLabel.text = song.title
		
		return cell
	}
	
	override func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
		if indexPath.row == self.paginator.fetchedResources.count - 1 {
			self.loadNextPage()
		}
	}
}