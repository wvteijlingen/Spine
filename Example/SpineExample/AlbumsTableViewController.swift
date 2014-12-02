//
//  AlbumsTableViewController.swift
//  SpineExample
//
//  Created by Ward van Teijlingen on 08-09-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import UIKit
import Spine

class AlbumsTableViewController: UITableViewController {

	var artist: Artist!
	var albums: [Album] = []
	
	override func viewDidLoad() {
		super.viewDidLoad()
		self.title = self.artist.name
		self.refreshData()
	}
	
	/// Refresh the table view if the data is loaded, otherwise load the data.
	func refreshData() {
		self.artist.albums?.ifLoaded { resources in
			self.albums = resources as [Album]
			self.tableView.reloadData()
		}.ifNotLoaded {
			self.loadData()
		}
	}
	
	/// Load the data and call `refreshData` on success.
	func loadData() {
		self.artist.albums!.ensureResources { query in
			query.include("songs")
			return
		}.onSuccess { resources in
			self.artist.albums!.fulfill(resources)
			self.refreshData()
		}.onFailure { error in
			var alert = UIAlertController(title: "Error loading albums", message: error.localizedDescription, preferredStyle: UIAlertControllerStyle.Alert)
			alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.Default, handler: nil))
			self.presentViewController(alert, animated: true, completion: nil)
		}
	}
	
	
	
	// MARK: - Table view data source
	
	override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
		return self.albums.count
	}
	
	override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return self.albums[section].songs!.count
	}
	
	override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		let album = self.albums[section]
		return album.title
	}
	
	override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCellWithIdentifier("SongCell", forIndexPath: indexPath) as UITableViewCell
		
		let album = self.albums[indexPath.section]
		let song = album.songs?.resources![indexPath.row] as? Song
		
		cell.textLabel.text = song!.title
		
		return cell
	}
}
