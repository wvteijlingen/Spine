//
//  ArtistsTableViewController.swift
//  SpineExample
//
//  Created by Ward van Teijlingen on 08-09-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import UIKit
import Spine

class ArtistsTableViewController: UITableViewController {

	var artists: [Artist] = []
	
    override func viewDidLoad() {
        super.viewDidLoad()
		self.loadData()
    }
	
	func loadData() {
		Artist.findAll().onSuccess { resources in
			self.artists = resources as [Artist]
			self.tableView.reloadData()
		}.onFailure { error in
			var alert = UIAlertController(title: "Error loading artists", message: error.localizedDescription, preferredStyle: UIAlertControllerStyle.Alert)
			alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.Default, handler: nil))
			self.presentViewController(alert, animated: true, completion: nil)
		}
	}

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.artists.count
    }
	
	override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCellWithIdentifier("ArtistCell", forIndexPath: indexPath) as UITableViewCell
		let artist = self.artists[indexPath.row]
		
		cell.textLabel?.text = artist.name
		cell.detailTextLabel?.text = artist.website
		
		return cell
	}
	
	
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject!) {
		if segue.identifier == "AlbumDetail" {
			(segue.destinationViewController as AlbumsTableViewController).artist = self.artists[self.tableView.indexPathForSelectedRow()!.row]
		}
    }


}
