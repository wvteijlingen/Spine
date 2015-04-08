//
//  Errors.swift
//  Spine
//
//  Created by Ward van Teijlingen on 07-04-15.
//  Copyright (c) 2015 Ward van Teijlingen. All rights reserved.
//

import Foundation

/// The domain used for errors that occur within the Spine framework.
public let SpineClientErrorDomain = "com.wardvanteijlingen.spine.client"

/// The domain used for errors that are returned by the API.
public let SpineServerErrorDomain = "com.wardvanteijlingen.spine.server"

/// Error codes
public struct SpineErrorCodes {
	/// The given JSON document could not be parsed, because it is in an unsupported structure.
	public static let InvalidDocumentStructure = 1
	
	/// The next page of a collection is not available.
	public static let NextPageNotAvailable = 10
	
	/// The previous page of a collection is not available.
	public static let PreviousPageNotAvailable = 11
	
	/// The given resource coulde not be found.
	public static let ResourceNotFound = 404
}