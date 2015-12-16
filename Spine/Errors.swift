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

/// The domain used for errors that occur within serializing and deserializing.
public let SpineSerializingErrorDomain = "com.wardvanteijlingen.spine.serializing"

/// The domain used for errors that are returned by the API.
public let SpineServerErrorDomain = "com.wardvanteijlingen.spine.server"

/// Error codes
public struct SpineErrorCodes {
	/// An unknown error occured.
	public static let UnknownError = 0
	
	/// The given JSON document could not be parsed, because it is in an unsupported structure.
	public static let InvalidDocumentStructure = 1
	
	/// The given JSON resource could not be parsed, because it is in an unsupported structure.
	public static let InvalidResourceStructure = 2
	
	public static let ResourceTypeMissing = 3
	public static let ResourceIDMissing = 4
	
	/// The next page of a collection is not available.
	public static let NextPageNotAvailable = 10
	
	/// The previous page of a collection is not available.
	public static let PreviousPageNotAvailable = 11
	
	/// The given resource coulde not be found.
	public static let ResourceNotFound = 404
}