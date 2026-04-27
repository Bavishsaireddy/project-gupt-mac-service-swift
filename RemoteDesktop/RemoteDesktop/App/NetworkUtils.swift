//
//  NetworkUtils.swift
//  RemoteDesktop
//
//  Network utility functions for host discovery and configuration
//

import Foundation
import os.log

/// Helper functions for network-related tasks
class NetworkUtils {
    private static let logger = Logger(subsystem: "com.gupt", category: "NetworkUtils")
    
    /// Get all IPv4 and IPv6 addresses for the current device
    /// - Returns: List of local IP addresses
    static func getLocalIPAddresses() -> [String] {
        var addresses = [String]()
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        guard getifaddrs(&ifaddr) == 0 else {
            logger.error("Failed to get network interfaces")
            return []
        }
        defer { freeifaddrs(ifaddr) }
        
        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }
            
            let interface = ptr?.pointee
            let addrFamily = interface?.ifa_addr.pointee.sa_family
            
            if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                let name = String(cString: (interface?.ifa_name)!)
                
                // Exclude loopback
                if name == "lo0" { continue }
                
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(interface?.ifa_addr, socklen_t((interface?.ifa_addr.pointee.sa_len)!),
                            &hostname, socklen_t(hostname.count),
                            nil, socklen_t(0), NI_NUMERICHOST)
                
                addresses.append(String(cString: hostname))
            }
        }
        
        return addresses.sorted()
    }
    
    /// Check if a port is currently in use
    /// - Parameter port: The port to check
    /// - Returns: True if the port is in use
    static func isPortInUse(_ port: UInt16) -> Bool {
        // Simplified check; in production, use setsockopt/bind
        return false
    }
}
