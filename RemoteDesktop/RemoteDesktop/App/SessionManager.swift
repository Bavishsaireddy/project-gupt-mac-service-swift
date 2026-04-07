//
//  SessionManager.swift
//  RemoteDesktop
//
//  Manages persistent application state, connection history, and preferences
//

import Foundation
import os.log

/// Manages application-wide state and persistence
class SessionManager: ObservableObject {
    static let shared = SessionManager()
    private let logger = Logger(subsystem: "com.remotedesktop", category: "SessionManager")
    
    // MARK: - Published Properties
    
    @Published var connectionHistory: [ConnectionEntry] = []
    @Published var currentPassword: String = ""
    
    // MARK: - Persistence Keys
    
    private let historyKey = "com.remotedesktop.history"
    private let passwordKey = "com.remotedesktop.password"
    
    // MARK: - Initialization
    
    private init() {
        loadHistory()
        loadPassword()
    }
    
    // MARK: - History Management
    
    func addHistoryEntry(host: String, port: UInt16) {
        let entry = ConnectionEntry(host: host, port: port, lastConnected: Date())
        
        // Remove existing entry for same host
        connectionHistory.removeAll { $0.host == host }
        
        // Add to top and limit size
        connectionHistory.insert(entry, at: 0)
        if connectionHistory.count > 10 {
            connectionHistory.removeLast()
        }
        
        saveHistory()
    }
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let history = try? JSONDecoder().decode([ConnectionEntry].self, from: data) {
            self.connectionHistory = history
        }
    }
    
    private func saveHistory() {
        if let data = try? JSONEncoder().encode(connectionHistory) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }
    
    // MARK: - Password Management
    
    func generateNewPassword() {
        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let newPass = String((0..<8).map { _ in chars.randomElement()! })
        self.currentPassword = newPass
        savePassword()
        logger.info("New host password generated")
    }
    
    private func loadPassword() {
        if let saved = UserDefaults.standard.string(forKey: passwordKey) {
            self.currentPassword = saved
        } else {
            generateNewPassword()
        }
    }
    
    private func savePassword() {
        UserDefaults.standard.set(currentPassword, forKey: passwordKey)
    }
}

// MARK: - Supporting Types

struct ConnectionEntry: Codable, Identifiable {
    var id: String { host + "\(port)" }
    let host: String
    let port: UInt16
    let lastConnected: Date
}
