//
//  SessionManager.swift
//  GUPT
//
//  Manages persistent application state, connection history, and preferences
//

import Foundation
import os.log

/// Manages application-wide state and persistence
class SessionManager: ObservableObject {
    static let shared = SessionManager()
    private let logger = Logger(subsystem: "com.gupt", category: "SessionManager")
    
    // MARK: - Published Properties
    
    @Published var connectionHistory: [ConnectionEntry] = []
    @Published var currentPassword: String = ""
    @Published var relayServerURL: String = "ws://localhost:3900"
    
    // MARK: - Persistence Keys
    
    private let historyKey = "com.gupt.history"
    private let passwordKey = "com.gupt.password"
    private let relayServerKey = "com.gupt.relayserver"
    
    // MARK: - Initialization
    
    private init() {
        loadHistory()
        loadPassword()
        loadRelayServer()
    }
    
    // MARK: - History Management
    
    func addHistoryEntry(roomCode: String) {
        let entry = ConnectionEntry(roomCode: roomCode, lastConnected: Date())
        
        // Remove existing entry for same room
        connectionHistory.removeAll { $0.roomCode == roomCode }
        
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

    func updateRelayServer(_ url: String) {
        relayServerURL = url
        UserDefaults.standard.set(url, forKey: relayServerKey)
    }

    private func loadRelayServer() {
        if let url = UserDefaults.standard.string(forKey: relayServerKey) {
            relayServerURL = url
        }
    }
}

// MARK: - Models

struct ConnectionEntry: Codable, Identifiable {
    var id: String { roomCode }
    let roomCode: String
    let lastConnected: Date
}
