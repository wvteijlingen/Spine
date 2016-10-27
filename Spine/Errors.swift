//
//  Errors.swift
//  Spine
//
//  Created by Ward van Teijlingen on 07-04-15.
//  Copyright (c) 2015 Ward van Teijlingen. All rights reserved.
//

import Foundation

/// An error returned from the server.
public struct APIError: Error, Equatable {
	public var id: String?
	public var status: String?
	public var code: String?
	public var title: String?
	public var detail: String?
	public var sourcePointer: String?
	public var sourceParameter: String?
	public var meta: [String: Any]?
	
	init(id: String?, status: String?, code: String?, title: String?, detail: String?, sourcePointer: String?, sourceParameter: String?, meta: [String: Any]?) {
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
public enum SpineError: Error, Equatable {
	case unknownError
	
	/// The next page of a collection is not available.
	case nextPageNotAvailable
	
	/// The previous page of a collection is not available.
	case previousPageNotAvailable
	
	/// The requested resource is not found.
	case resourceNotFound
	
	/// An error occured during (de)serializing.
	case serializerError(SerializerError)
	
	/// A error response was received from the API.
	case serverError(statusCode: Int, apiErrors: [APIError]?)
	
	/// A network error occured.
	case networkError(NSError)
}

public enum SerializerError: Error, Equatable {
	case unknownError
	
	/// The given JSON is not a dictionary (hash).
	case invalidDocumentStructure
	
	/// None of 'data', 'errors', or 'meta' is present in the top level.
	case topLevelEntryMissing
	
	/// Top level 'data' and 'errors' coexist in the same document.
	case topLevelDataAndErrorsCoexist
	
	/// The given JSON is not a dictionary (hash).
	case invalidResourceStructure
	
	/// 'Type' field is missing from resource JSON.
	case resourceTypeMissing
	
	/// The given resource type has not been registered to Spine.
    case resourceTypeUnregistered(ResourceType)
	
	/// 'ID' field is missing from resource JSON.
	case resourceIDMissing
	
	/// Error occurred in NSJSONSerialization
	case jsonSerializationError(NSError)
}


public func ==(lhs: SpineError, rhs: SpineError) -> Bool {
	switch (lhs, rhs) {
	case (.unknownError, .unknownError):
		return true
	case (.nextPageNotAvailable, .nextPageNotAvailable):
		return true
	case (.previousPageNotAvailable, .previousPageNotAvailable):
		return true
	case (.resourceNotFound, .resourceNotFound):
		return true
	case (let .serializerError(lhsError), let .serializerError(rhsError)):
		return lhsError == rhsError
	case (let .serverError(lhsStatusCode, lhsApiErrors), let .serverError(rhsStatusCode, rhsApiErrors)):
		if lhsStatusCode != rhsStatusCode { return false }
		if lhsApiErrors == nil && rhsApiErrors == nil { return true }
		if let lhsErrors = lhsApiErrors, let rhsErrors = rhsApiErrors {
			return lhsErrors == rhsErrors
		}
		return false
	case (let .networkError(lhsError), let .networkError(rhsError)):
		return lhsError == rhsError
	default:
		return false
	}
}

public func ==(lhs: SerializerError, rhs: SerializerError) -> Bool {
	switch (lhs, rhs) {
	case (.unknownError, .unknownError):
		return true
	case (.invalidDocumentStructure, .invalidDocumentStructure):
		return true
	case (.topLevelEntryMissing, .topLevelEntryMissing):
		return true
	case (.topLevelDataAndErrorsCoexist, .topLevelDataAndErrorsCoexist):
		return true
	case (.invalidResourceStructure, .invalidResourceStructure):
		return true
	case (.resourceTypeMissing, .resourceTypeMissing):
		return true
	case (.resourceIDMissing, .resourceIDMissing):
		return true
	case (let .jsonSerializationError(lhsError), let .jsonSerializationError(rhsError)):
		return lhsError == rhsError
	default:
		return false
	}
}
