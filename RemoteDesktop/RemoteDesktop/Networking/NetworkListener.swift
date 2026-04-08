//
//  NetworkListener.swift
//  RemoteDesktop
//
//  Server-side network listener using NWListener
//

import Foundation
import Network
import os.log

/// Delegate protocol for listener events
protocol NetworkListenerDelegate: AnyObject {
    func listener(_ listener: NetworkListener, didAcceptConnection connection: NetworkConnection)
    func listener(_ listener: NetworkListener, didEncounterError error: Error)
    func listener(_ listener: NetworkListener, didChangeState state: NWListener.State)
}

/// Host-side network listener
@available(macOS 10.14, *)
class NetworkListener {
    private var listener: NWListener?
    private let port: UInt16
    private let useTLS: Bool
    private let queue: DispatchQueue
    private let logger = Logger(subsystem: "com.remotedesktop", category: "NetworkListener")

    weak var delegate: NetworkListenerDelegate?

    private(set) var isRunning = false

    // MARK: - Initialization

    init(port: UInt16, useTLS: Bool = true) {
        self.port = port
        self.useTLS = useTLS
        self.queue = DispatchQueue(label: "com.remotedesktop.listener", qos: .userInteractive)
    }

    // MARK: - Listener Management

    /// Start listening for connections
    func start() throws {
        guard listener == nil else {
            logger.warning("Listener already running")
            return
        }

        // Configure TCP options
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.noDelay = true
        tcpOptions.enableKeepalive = true
        tcpOptions.keepaliveInterval = 5

        let parameters: NWParameters
        if useTLS {
            parameters = configureTLSParameters()
            // We shouldn't overwrite the TLS transport here manually unless done during setup
        } else {
            parameters = NWParameters(tls: nil, tcp: tcpOptions)
        }

        // Allow local and peer-to-peer connections
        parameters.acceptLocalOnly = false
        parameters.allowLocalEndpointReuse = true
        parameters.allowLocalEndpointReuse = true

        do {
            let nwPort = NWEndpoint.Port(rawValue: port)!
            let newListener = try NWListener(using: parameters, on: nwPort)

            newListener.stateUpdateHandler = { [weak self] newState in
                self?.handleStateUpdate(newState)
            }

            newListener.newConnectionHandler = { [weak self] newConnection in
                self?.handleNewConnection(newConnection)
            }

            newListener.start(queue: queue)
            self.listener = newListener
            self.isRunning = true

            logger.info("Listener started on port \(self.port)")
        } catch {
            logger.error("Failed to start listener: \(error.localizedDescription)")
            throw error
        }
    }

    /// Stop listening
    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
        logger.info("Listener stopped")
    }

    private func handleStateUpdate(_ newState: NWListener.State) {
        logger.info("Listener state: \(String(describing: newState))")
        delegate?.listener(self, didChangeState: newState)

        switch newState {
        case .ready:
            logger.info("Listener ready on port \(self.port)")

        case .failed(let error):
            logger.error("Listener failed: \(error.localizedDescription)")
            delegate?.listener(self, didEncounterError: error)
            isRunning = false

        case .cancelled:
            isRunning = false

        default:
            break
        }
    }

    private func handleNewConnection(_ nwConnection: NWConnection) {
        logger.info("New connection from \(String(describing: nwConnection.endpoint))")

        Task {
            let connection = NetworkConnection(connection: nwConnection)
            // Connection should be started by the delegate after assignment
            delegate?.listener(self, didAcceptConnection: connection)
        }
    }

    // MARK: - TLS Configuration

    private func configureTLSParameters() -> NWParameters {
        let tlsOptions = NWProtocolTLS.Options()

        // Load or generate TLS certificate
        // For initial implementation, use self-signed certificate
        // TODO: Implement proper certificate management

        let secOptions = tlsOptions.securityProtocolOptions

        // Set minimum TLS version
        sec_protocol_options_set_min_tls_protocol_version(secOptions, .TLSv13)

        // For now, generate ephemeral identity
        // In production, load from keychain or file
        if let identity = createSelfSignedIdentity() {
            sec_protocol_options_set_local_identity(secOptions, identity)
        }

        let parameters = NWParameters(tls: tlsOptions, tcp: NWProtocolTCP.Options())
        return parameters
    }

    private func createSelfSignedIdentity() -> sec_identity_t? {
        // Create a self-signed certificate for TLS
        // This is a simplified version - in production, use proper certificate management

        let keyParams: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 2048
        ]

        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(keyParams as CFDictionary, &error) else {
            if let error = error {
                logger.error("Failed to create private key: \(error.takeRetainedValue().localizedDescription)")
            }
            return nil
        }

        // Create certificate (simplified - use proper X.509 certificate in production)
        // For now, return nil and rely on unverified TLS
        // TODO: Implement proper certificate generation using Security framework

        return nil
    }

    // MARK: - Utility

    /// Get local IP addresses
    static func getLocalIPAddresses() -> [String] {
        var addresses: [String] = []

        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return [] }
        defer { freeifaddrs(ifaddr) }

        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }

            guard let interface = ptr?.pointee else { continue }
            let addrFamily = interface.ifa_addr.pointee.sa_family

            if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                let name = String(cString: interface.ifa_name)

                // Skip loopback and inactive interfaces
                guard name != "lo0" && (interface.ifa_flags & UInt32(IFF_UP)) != 0 else {
                    continue
                }

                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(
                    interface.ifa_addr,
                    socklen_t(interface.ifa_addr.pointee.sa_len),
                    &hostname,
                    socklen_t(hostname.count),
                    nil,
                    0,
                    NI_NUMERICHOST
                ) == 0 {
                    let address = String(cString: hostname)
                    // Filter out IPv6 link-local addresses
                    if !address.hasPrefix("fe80:") {
                        addresses.append(address)
                    }
                }
            }
        }

        return addresses
    }

    var localAddresses: [String] {
        Self.getLocalIPAddresses()
    }
}
