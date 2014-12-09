//
//  Meta.swift
//  SpineExample
//
//  Created by Ward van Teijlingen on 09-09-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Spine

class ResponseMeta: Meta {
	var page: NSNumber?
	var pageSize: NSNumber?
	var count: NSNumber?
	var include: [String]?
	var totalPageCount: NSNumber?
	var previousPage: NSNumber?
	var nextPage: NSNumber?
	var previousHref: String?
	var nextHref: String?

	override var persistentAttributes: [String: ResourceAttribute] {
		return [
			"page": ResourceAttribute(type: .Property, representationName: "page"),
			"pageSize": ResourceAttribute(type: .Property, representationName: "page_size"),
			"count": ResourceAttribute(type: .Property, representationName: "count"),
			"include": ResourceAttribute(type: .Property, representationName: "include"),
			"totalPageCount": ResourceAttribute(type: .Property, representationName: "page_count"),
			"previousPage": ResourceAttribute(type: .Property, representationName: "previous_page"),
			"nextPage": ResourceAttribute(type: .Property, representationName: "next_page"),
			"previousHref": ResourceAttribute(type: .Property, representationName: "previous_href"),
			"nextHref": ResourceAttribute(type: .Property, representationName: "next_href")
			]
	}

	// MARK: Paginatable
	var firstPage: Int {
		return 1
	}
	
	var lastPage: Int {
		return self.totalPageCount?.integerValue ?? Int.max
	}
	
	var currentPage: Int {
		return self.page?.integerValue ?? 0
	}
	
	var nextPageURL: String? {
		return self.nextHref
	}
	
	var previousPageURL: String? {
		return self.previousHref
	}
}