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
		case .Debug:   return "❔ Debug  "
		case .Info:    return "❕ Info   "
		case .Warning: return "❗️ Warning"
		case .Error:   return "❌ Error  "
		case .None:    return "None      "
		}
	}
}

/**
Logging domains

- Spine:       The main Spine component
- Networking:  The networking component, requests, responses etc
- Serializing: The (de)serializing component
*/
public enum LogDomain {
	case Spine, Networking, Serializing
}

/// Configured log levels
internal var logLevels: [LogDomain: LogLevel] = [
	.Spine: .None,
	.Networking: .None,
	.Serializing: .None
]

/**
Extension regarding logging.
*/
extension Spine {
	public class func setLogLevel(level: LogLevel, forDomain domain: LogDomain) {
		logLevels[domain] = level
	}
	
	class func shouldLog(level: LogLevel, domain: LogDomain) -> Bool {
		return (level.rawValue >= logLevels[domain]?.rawValue)
	}
	
	class func log<T>(object: T, level: LogLevel, domain: LogDomain) {
		if shouldLog(level, domain: domain) {
			print("\(level.description) - \(object)")
		}
	}
	
	class func logDebug<T>(domain: LogDomain, _ object: T) {
		log(object, level: .Debug, domain: domain)
	}
	
	class func logInfo<T>(domain: LogDomain, _ object: T) {
		log(object, level: .Info, domain: domain)
	}
	
	class func logWarning<T>(domain: LogDomain, _ object: T) {
		log(object, level: .Warning, domain: domain)
	}
	
	class func logError<T>(domain: LogDomain, _ object: T) {
		log(object, level: .Error, domain: domain)
	}
}
