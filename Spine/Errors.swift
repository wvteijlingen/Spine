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

/// TODO: Ideally this is a struct, but we can't store structs in the userInfo of an NSError.
/// The correct thing to do would probably be to replace NSError with a Spine Error enum.
/// In the meantime, this is a class so we can still work with the current NSError infrastructure.
public class APIError: ErrorType {
	public var id: String?
	public var status: String?
	public var code: String?
	public var title: String?
	public var detail: String?
	public var sourcePointer: String?
	public var sourceParameter: String?
	public var meta: [String: AnyObject]?
	
	init(id: String?, status: String?, code: String?, title: String?, detail: String?, sourcePointer: String?, sourceParameter: String?, meta: [String: AnyObject]?) {
		self.id = id
		self.status = status
		self.code = code
		self.title = title
		self.detail = detail
		self.sourcePointer = sourcePointer
		self.sourceParameter = sourceParameter
		self.meta = meta
	}
}

public enum SpineError: ErrorType {
	case UnknownError
	case NextPageNotAvailable
	case PreviousPageNotAvailable
	case ResourceNotFound
	case SerializerError
	case ServerError(statusCode: Int, apiErrors: [APIError]?)
	case NetworkError(NSError)
}

public enum SerializerError: ErrorType {
	case UnknownError
	
	/// The given JSON is not a dictionary (hash).
	case InvalidDocumentStructure
	
	/// None of 'data', 'errors', or 'meta' is present in the top level.
	case TopLevelEntryMissing
	
	/// Top level 'data' and 'errors' coexist in the same document.
	case TopLevelDataAndErrorsCoexist
	
	/// The given JSON is not a dictionary (hash).
	case InvalidResourceStructure
	
	/// 'Type' field is missing from resource JSON.
	case ResourceTypeMissing
	
	/// 'ID' field is missing from resource JSON.
	case ResourceIDMissing
	
	/// Error occurred in NSJSONSerialization
	case JSONSerializationError(NSError)
}