//
//  Logger.swift
//  RemoteDesktop
//
//  Unified logging utility for the application
//

import Foundation
import os.log

/// Unified logging system using os.Log
class AppLogger {
    static let shared = AppLogger()
    
    private let subsystem = "com.gupt"
    
    /// Create a logger for a specific category
    func logger(for category: String) -> Logger {
        return Logger(subsystem: subsystem, category: category)
    }
    
    /// Log a message with a specific level
    func log(_ message: String, level: OSLogType = .default, category: String = "General") {
        let logger = self.logger(for: category)
        
        switch level {
        case .debug: logger.debug("\(message)")
        case .info: logger.info("\(message)")
        case .error: logger.error("\(message)")
        case .fault: logger.fault("\(message)")
        default: logger.log("\(message)")
        }
    }
    
    // MARK: - Convenience Methods
    
    static func debug(_ message: String, category: String = "General") {
        shared.log(message, level: .debug, category: category)
    }
    
    static func info(_ message: String, category: String = "General") {
        shared.log(message, level: .info, category: category)
    }
    
    static func error(_ message: String, category: String = "General") {
        shared.log(message, level: .error, category: category)
    }
}
