//
//  Errors.swift
//  Spine
//
//  Created by Ward van Teijlingen on 07-04-15.
//  Copyright (c) 2015 Ward van Teijlingen. All rights reserved.
//

import Foundation

/// An error returned from the server.
public struct APIError: ErrorType, Equatable {
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

public func ==(lhs: APIError, rhs: APIError) -> Bool {
	return lhs.code == rhs.code
}

/// An error that occured in Spine.
public enum SpineError: ErrorType, Equatable {
	case UnknownError
	
	/// The next page of a collection is not available.
	case NextPageNotAvailable
	
	/// The previous page of a collection is not available.
	case PreviousPageNotAvailable
	
	/// The requested resource is not found.
	case ResourceNotFound
	
	/// An error occured during (de)serializing.
	case SerializerError
	
	/// A error response was received from the API.
	case ServerError(statusCode: Int, apiErrors: [APIError]?)
	
	/// A network error occured.
	case NetworkError(NSError)
}

public enum SerializerError: ErrorType, Equatable {
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


public func ==(lhs: SpineError, rhs: SpineError) -> Bool {
	switch (lhs, rhs) {
	case (.UnknownError, .UnknownError):
		return true
	case (.NextPageNotAvailable, .NextPageNotAvailable):
		return true
	case (.PreviousPageNotAvailable, .PreviousPageNotAvailable):
		return true
	case (.ResourceNotFound, .ResourceNotFound):
		return true
	case (.SerializerError, .SerializerError):
		return true
	case (let .ServerError(lhsStatusCode, lhsApiErrors), let .ServerError(rhsStatusCode, rhsApiErrors)):
		if lhsStatusCode != rhsStatusCode { return false }
		if lhsApiErrors == nil && rhsApiErrors == nil { return true }
		if let lhsErrors = lhsApiErrors, rhsErrors = rhsApiErrors {
			return lhsErrors == rhsErrors
		}
		return false
	case (let .NetworkError(lhsError), let .NetworkError(rhsError)):
		return lhsError == rhsError
	default:
		return false
	}
}

public func ==(lhs: SerializerError, rhs: SerializerError) -> Bool {
	switch (lhs, rhs) {
	case (.UnknownError, .UnknownError):
		return true
	case (.InvalidDocumentStructure, .InvalidDocumentStructure):
		return true
	case (.TopLevelEntryMissing, .TopLevelEntryMissing):
		return true
	case (.TopLevelDataAndErrorsCoexist, .TopLevelDataAndErrorsCoexist):
		return true
	case (.InvalidResourceStructure, .InvalidResourceStructure):
		return true
	case (.ResourceTypeMissing, .ResourceTypeMissing):
		return true
	case (.ResourceIDMissing, .ResourceIDMissing):
		return true
	case (let .JSONSerializationError(lhsError), let .JSONSerializationError(rhsError)):
		return lhsError == rhsError
	default:
		return false
	}
}