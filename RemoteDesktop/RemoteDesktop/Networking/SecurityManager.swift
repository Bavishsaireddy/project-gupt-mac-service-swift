//
//  SecurityManager.swift
//  RemoteDesktop
//
//  Authentication and security management
//

import Foundation
import CryptoKit

/// Manages authentication and security
actor SecurityManager {
    private var passwordHash: String?
    private var activeSessions: [String: Session] = [:]

    struct Session {
        let token: String
        let createdAt: Date
        let expiresAt: Date
        let clientInfo: String
    }

    // MARK: - Password Management

    /// Set the server password
    func setPassword(_ password: String) {
        let salt = generateSalt()
        self.passwordHash = hashPassword(password, salt: salt)
    }

    /// Verify password with salt
    func verifyPassword(_ password: String, salt: String) -> Bool {
        guard let storedHash = passwordHash else { return false }
        let computedHash = hashPassword(password, salt: salt)
        return computedHash == storedHash
    }

    /// Hash password using SHA-256
    private func hashPassword(_ password: String, salt: String) -> String {
        let combined = password + salt
        let inputData = Data(combined.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Generate random salt
    private func generateSalt() -> String {
        let saltData = (0..<16).map { _ in UInt8.random(in: 0...255) }
        return saltData.map { String(format: "%02x", $0) }.joined()
    }

    /// Generate salt for client
    func generateClientSalt() -> String {
        return generateSalt()
    }

    // MARK: - Session Management

    /// Create a new session
    func createSession(for clientInfo: String, duration: TimeInterval = 3600) -> String {
        let token = generateSessionToken()
        let now = Date()

        let session = Session(
            token: token,
            createdAt: now,
            expiresAt: now.addingTimeInterval(duration),
            clientInfo: clientInfo
        )

        activeSessions[token] = session
        return token
    }

    /// Validate session token
    func validateSession(_ token: String) -> Bool {
        guard let session = activeSessions[token] else {
            return false
        }

        if session.expiresAt < Date() {
            // Session expired
            activeSessions.removeValue(forKey: token)
            return false
        }

        return true
    }

    /// Revoke session
    func revokeSession(_ token: String) {
        activeSessions.removeValue(forKey: token)
    }

    /// Revoke all sessions
    func revokeAllSessions() {
        activeSessions.removeAll()
    }

    private func generateSessionToken() -> String {
        let tokenData = (0..<32).map { _ in UInt8.random(in: 0...255) }
        return tokenData.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Authentication Flow

    /// Process authentication request
    func authenticate(username: String?, passwordHash: String, salt: String, clientInfo: String) -> AuthResponseMessage {
        // For initial version, we only check password
        // Username can be used for multi-user support later

        // Verify password
        let password = passwordHash  // Client already hashed with salt
        guard verifyPassword(password, salt: salt) else {
            return AuthResponseMessage(
                success: false,
                sessionToken: nil,
                message: "Invalid password"
            )
        }

        // Create session
        let token = createSession(for: clientInfo)

        return AuthResponseMessage(
            success: true,
            sessionToken: token,
            message: "Authentication successful"
        )
    }

    // MARK: - Certificate Management (for future use)

    /// Load TLS certificate
    func loadCertificate(from path: String) -> SecIdentity? {
        // TODO: Implement certificate loading from file or keychain
        // For now, return nil and use ephemeral certificates
        return nil
    }

    /// Generate self-signed certificate
    func generateSelfSignedCertificate() -> SecIdentity? {
        // TODO: Implement self-signed certificate generation
        // Using Security framework to create X.509 certificate
        return nil
    }
}

// MARK: - Security Extensions

extension Data {
    /// Convert to hex string
    func hexString() -> String {
        return map { String(format: "%02x", $0) }.joined()
    }
}

extension String {
    /// Convert hex string to Data
    func hexData() -> Data? {
        var data = Data(capacity: count / 2)
        var index = startIndex

        while index < endIndex {
            let nextIndex = self.index(index, offsetBy: 2)
            if let byte = UInt8(self[index..<nextIndex], radix: 16) {
                data.append(byte)
            } else {
                return nil
            }
            index = nextIndex
        }

        return data
    }
}
