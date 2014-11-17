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
		self.loadData()
	}
	
	func loadData() {
		let query = Query(resource: self.artist, relationship: "albums").include("songs")
		
		query.findResources().onSuccess { resources, meta in
			self.albums = resources as [Album]
			self.tableView.reloadData()
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
		var album = self.albums[section]
		
		if let songs = self.albums[section].songs {
			return songs.count
		} else {
			return 0
		}
	}
	
	override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		let album = self.albums[section]
		return album.title
	}
	
	override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCellWithIdentifier("SongCell", forIndexPath: indexPath) as UITableViewCell
		
		let album = self.albums[indexPath.section]
		let song = album.songs![indexPath.row]
		
		cell.textLabel.text = song.title
		
		return cell
	}
}
