//
//  Paginator.swift
//  Spine
//
//  Created by Ward van Teijlingen on 09-09-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation
import BrightFutures

@objc public protocol Paginatable {
	var firstPage: Int { get }
	var lastPage: Int { get }
	var currentPage: Int { get }
	var nextPageURL: String? { get }
	var previousPageURL: String? { get }
}

public class Paginator {
	
	private var spine: Spine
	private var query: Query
	private var paginationData: Paginatable?
	
	/// The current page.
	public var currentPage: Int {
		get {
			if let paginationData = self.paginationData {
				return paginationData.currentPage
			} else if let page = query.page {
				return page
			} else {
				return 1
			}
		}
		set(newValue) {
			query.page = newValue
		}
	}
	
	/// The amount of items per page.
	/// You must configure this in the query, it cannot be changed afterwards.
	public var pageSize: Int? {
		return _pageSize
	}
	private var _pageSize: Int?
	
	
	/// Returns whether the next page can be fetched.
	public var canFetchNextPage: Bool {
		if let paginationData = self.paginationData {
			return paginationData.currentPage < paginationData.lastPage
		}
			
		return true
	}
	
	/// Returns whether the previous page can be fetched.
	public var canFetchPreviousPage: Bool {
		if let paginationData = self.paginationData {
			return paginationData.currentPage > paginationData.firstPage
		}
			
		return false
	}
	
	
	/// The cumulative fetched resources
	public var fetchedResources : [Resource] = []
	
	
	public init(query: Query) {
		self.spine = Spine.sharedInstance
		self.query = query
		self._pageSize = query.pageSize
	}
	
	public init(spine: Spine, query: Query) {
		self.spine = spine
		self.query = query
	}
	
	/**
	Fetches the next page.
	You must make sure the next page can be fetched using `canFetchNextPage`.
	
	:returns: A future containing the new resources fetched and optional meta.
	*/
	public func fetchNextPage() -> Future<([Resource], Meta?)> {
		assert(self.canFetchNextPage, "Cannot fetch the next page.")
		
		if self.paginationData != nil {
			self.currentPage += 1
		}
		
		return self.performFetch()
	}
	
	/**
	Fetches the previous page.
	You must make sure the previous page can be fetched using `canFetchPreviousPage`.
	
	:returns: A future containing the new resources fetched and optional meta.
	*/
	public func fetchPreviousPage() -> Future<([Resource], Meta?)> {
		assert(self.canFetchPreviousPage, "Cannot fetch the previous page.")
		
		if self.paginationData != nil {
			self.currentPage -= 1
		}
		
		return self.performFetch()
	}
	
	
	private func performFetch() -> Future<([Resource], Meta?)> {
		let promise = Promise<([Resource], Meta?)>()
		
		self.spine.fetchResourcesForQuery(self.query).onSuccess { resourceCollection, meta in
			assert(meta != nil, "No meta recieved. Paginator requires pagination data to be present in a meta section.")
			assert(meta!.conformsToProtocol(Paginatable), "The registered meta class does not conform to the Paginatable protocol.")
			
			let resources = resourceCollection.resources!
			self.paginationData = (meta as Paginatable)
			self.fetchedResources += resources
			
			promise.success(resources, meta)
		}.onFailure { error in
			promise.error(error)
		}
		
		return promise.future
	}
}