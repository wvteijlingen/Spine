//
//  Logging.swift
//  Spine
//
//  Created by Ward van Teijlingen on 05-04-15.
//  Copyright (c) 2015 Ward van Teijlingen. All rights reserved.
//

import Foundation
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

fileprivate func >= <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l >= r
  default:
    return !(lhs < rhs)
  }
}


public enum LogLevel: Int {
	case debug = 0
	case info = 1
	case warning = 2
	case error = 3
	case none = 4
	
	var description: String {
		switch self {
		case .debug:   return "Debug   "
		case .info:    return "Info    "
		case .warning: return "Warning "
		case .error:   return "Error   "
		case .none:    return "None    "
		}
	}
}

/// Logging domains
///
/// - spine:       The main Spine component.
/// - networking:  The networking component, requests, responses etc.
/// - serializing: The (de)serializing component.
public enum LogDomain {
	case spine, networking, serializing
}

private var logLevels: [LogDomain: LogLevel] = [.spine: .none, .networking: .none, .serializing: .none]

/// Extension regarding logging.
extension Spine {
	public static var logger: Logger = ConsoleLogger()
	
	public class func setLogLevel(_ level: LogLevel, forDomain domain: LogDomain) {
		logLevels[domain] = level
	}
	
	class func shouldLog(_ level: LogLevel, domain: LogDomain) -> Bool {
		return (level.rawValue >= logLevels[domain]?.rawValue)
	}

	class func logDebug<T>(_ domain: LogDomain, _ object: T) {
		if shouldLog(.debug, domain: domain) {
			logger.log(object, level: .debug)
		}
	}
	
	class func logInfo<T>(_ domain: LogDomain, _ object: T) {
		if shouldLog(.info, domain: domain) {
			logger.log(object, level: .info)
		}
	}
	
	class func logWarning<T>(_ domain: LogDomain, _ object: T) {
		if shouldLog(.warning, domain: domain) {
			logger.log(object, level: .warning)
		}
	}
	
	class func logError<T>(_ domain: LogDomain, _ object: T) {
		if shouldLog(.error, domain: domain) {
			logger.log(object, level: .error)
		}
	}
}

public protocol Logger {
	/// Logs the textual representations of `object`.
	func log<T>(_ object: T, level: LogLevel)
}

/// Logger that logs to the console using the Swift built in `print` function.
struct ConsoleLogger: Logger {
	func log<T>(_ object: T, level: LogLevel) {
		print("\(level.description) - \(object)")
	}
}
