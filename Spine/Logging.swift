//
//  Logging.swift
//  Spine
//
//  Created by Ward van Teijlingen on 05-04-15.
//  Copyright (c) 2015 Ward van Teijlingen. All rights reserved.
//

import Foundation

public enum LogLevel: Int {
	case Debug = 0
	case Info = 1
	case Warning = 2
	case Error = 3
	case None = 4
	
	var description: String {
		switch self {
		case .Debug:   return "Debug   "
		case .Info:    return "Info    "
		case .Warning: return "Warning "
		case .Error:   return "Error   "
		case .None:    return "None    "
		}
	}
}

/**
Logging domains
- Spine:       The main Spine component.
- Networking:  The networking component, requests, responses etc.
- Serializing: The (de)serializing component.
*/
public enum LogDomain {
	case Spine, Networking, Serializing
}

private var logLevels: [LogDomain: LogLevel] = [.Spine: .None, .Networking: .None, .Serializing: .None]

/// Extension regarding logging.
extension Spine {
	public static var logger: Logger = ConsoleLogger()
	
	public class func setLogLevel(level: LogLevel, forDomain domain: LogDomain) {
		logLevels[domain] = level
	}
	
	class func shouldLog(level: LogLevel, domain: LogDomain) -> Bool {
		return (level.rawValue >= logLevels[domain]?.rawValue)
	}

	class func logDebug<T>(domain: LogDomain, _ object: T) {
		if shouldLog(.Debug, domain: domain) {
			logger.log(object, level: .Debug)
		}
	}
	
	class func logInfo<T>(domain: LogDomain, _ object: T) {
		if shouldLog(.Info, domain: domain) {
			logger.log(object, level: .Info)
		}
	}
	
	class func logWarning<T>(domain: LogDomain, _ object: T) {
		if shouldLog(.Warning, domain: domain) {
			logger.log(object, level: .Warning)
		}
	}
	
	class func logError<T>(domain: LogDomain, _ object: T) {
		if shouldLog(.Error, domain: domain) {
			logger.log(object, level: .Error)
		}
	}
}

public protocol Logger {
	/// Logs the textual representations of `object`.
	func log<T>(object: T, level: LogLevel)
}

/// Logger that logs to the console using the Swift built in `print` function.
struct ConsoleLogger: Logger {
	func log<T>(object: T, level: LogLevel) {
		print("\(level.description) - \(object)")
	}
}