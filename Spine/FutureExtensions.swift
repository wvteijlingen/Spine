//
//  FutureExtensions.swift
//  Spine
//
//  Created by Ward van Teijlingen on 05-04-15.
//  Copyright (c) 2015 Ward van Teijlingen. All rights reserved.
//

import Foundation
import BrightFutures

extension Future {
	func onServerFailure(callback: FailureCallback) -> BrightFutures.Future<T> {
		self.onFailure { error in
			if error.domain == SpineServerErrorDomain {
				callback(error)
			}
		}
		
		return self
	}
	
	func onNetworkFailure(callback: FailureCallback) -> BrightFutures.Future<T> {
		self.onFailure { error in
			if error.domain == NSURLErrorDomain {
				callback(error)
			}
		}
		
		return self
	}
	
	func onClientFailure(callback: FailureCallback) -> BrightFutures.Future<T> {
		self.onFailure { error in
			if error.domain == SpineClientErrorDomain {
				callback(error)
			}
		}
		
		return self
	}
}