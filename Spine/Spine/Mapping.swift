//
//  Mapping.swift
//  Spine
//
//  Created by Ward van Teijlingen on 23-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation
import SwiftyJSON

public class Mapper {
	
	var registeredClasses: [String: Resource.Type] = [:]
	
	
	// MARK: Custom classes
	
	public func registerType(type: Resource.Type, resourceType: String) {
		self.registeredClasses[resourceType] = type
	}
	
	public func classNameForResourceType(resourceType: String) -> Resource.Type {
		return self.registeredClasses[resourceType]!
	}

	
	// MARK: Response mapping
	
	/**
	Maps the response data into a resource store.
	
	:param: data The JSON data to map.
	
	:returns: The resource store containing the populated resources.
	*/
	func mapResponseData(data: JSONValue) -> ResourceStore {
		let mappingOperation = ResponseMappingOperation(responseData: data, mapper: self)
		mappingOperation.start()
		return mappingOperation.mappingResult!
	}

	func mapResponseData(data: JSONValue, usingStore store: ResourceStore) -> ResourceStore {
		let mappingOperation = ResponseMappingOperation(responseData: data, store: store, mapper: self)
		mappingOperation.start()
		return mappingOperation.mappingResult!
	}


	// MARK: Request mapping

	func mapResourcesToDictionary(resources: [Resource]) -> [String: [NSMutableDictionary]] {
		var dictionary: [String: [NSMutableDictionary]] = [:]
		
		//Loop through all resources
		for resource in resources {
			
			//Create a root resource key in the mapped dictionary
			let resourceType = resource.resourceType
			if dictionary[resourceType] == nil {
				dictionary[resourceType] = []
			}
			
			var values: NSMutableDictionary = NSMutableDictionary()
			var links: NSMutableDictionary = NSMutableDictionary()
			
			//Add the ID to the representation
			if let ID = resource.resourceID {
				values.setValue(ID, forKey: "id")
			}
			
			for (attributeName, attribute) in resource.persistentAttributes {
				switch attribute {
				
				//The attribute is a plain property, add it to the representation
				case .Property:
					values.setValue(resource.valueForKey(attributeName), forKey: attributeName)

				//The attribute is a date, format it as ISO-8601
				case .Date:
					let formatter = NSDateFormatter()
					formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
					values.setValue(formatter.stringFromDate(resource.valueForKey(attributeName) as NSDate), forKey: attributeName)
					
				//The attribute is a to-one relationship, add related ID, or null if no resource is related
				case .ToOne:
					if let relatedResource = resource.valueForKey(attributeName) as? Resource {
						links.setValue(relatedResource.resourceID, forKey: attributeName)
					} else {
						links.setValue(NSNull(), forKey: attributeName)
					}
					
				//The attribute is a to-many relationship, add related IDs, or an empty array if no resources are related
				case .ToMany:
					if let relatedResources = resource.valueForKey(attributeName) as? [Resource] {
						let IDs: [String] = relatedResources.map { (resource) in
							assert(resource.resourceID != nil, "Related resources must be saved before saving their parent resource.")
							return resource.resourceID!
						}
						links.setValue(IDs, forKey: attributeName)
					} else {
						links.setValue([], forKey: attributeName)
					}
				}
			}
			
			//If links were found, add them to the representation
			if links.allKeys.count != 0 {
				values.setValue(links, forKey: "links")
			}
			
			//Add the resoruce respresentation to the root dictionary
			dictionary[resourceType]!.append(values)
		}
		
		return dictionary
	}
}