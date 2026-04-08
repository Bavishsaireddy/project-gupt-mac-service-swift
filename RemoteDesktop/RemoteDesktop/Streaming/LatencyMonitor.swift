//
//  LatencyMonitor.swift
//  RemoteDesktop
//
//  Tracks end-to-end performance metrics for the video stream
//

import Foundation
import os.log

/// Tracks and calculates video stream performance metrics
class LatencyMonitor {
    static let shared = LatencyMonitor()
    private let logger = Logger(subsystem: "com.remotedesktop", category: "LatencyMonitor")
    
    struct Metrics {
        var captureLatency: Double = 0      // ms
        var encodeLatency: Double = 0       // ms
        var networkLatency: Double = 0      // ms
        var decodeLatency: Double = 0       // ms
        var renderLatency: Double = 0       // ms
        var totalLatency: Double = 0        // ms
        var fps: Double = 0
    }
    
    private(set) var currentMetrics = Metrics()
    
    private var lastFrameTime = Date()
    private var frameCount = 0
    private var lastFPSUpdate = Date()
    
    private let queue = DispatchQueue(label: "com.remotedesktop.latencymonitor", qos: .utility)
    
    // MARK: - Metrics Collection
    
    /// Reports the latency for a specific phase
    func reportPhaseLatency(phase: Phase, ms: Double) {
        queue.async {
            switch phase {
            case .capture: self.currentMetrics.captureLatency = ms
            case .encode: self.currentMetrics.encodeLatency = ms
            case .network: self.currentMetrics.networkLatency = ms
            case .decode: self.currentMetrics.decodeLatency = ms
            case .render: self.currentMetrics.renderLatency = ms
            }
            
            // Recalculate total latency (simplified sum)
            self.currentMetrics.totalLatency = self.currentMetrics.captureLatency +
                                               self.currentMetrics.encodeLatency +
                                               self.currentMetrics.networkLatency +
                                               self.currentMetrics.decodeLatency +
                                               self.currentMetrics.renderLatency
        }
    }
    
    /// Marks a frame as delivered to update FPS
    func reportFrameDelivered() {
        queue.async {
            self.frameCount += 1
            let now = Date()
            let elapsed = now.timeIntervalSince(self.lastFPSUpdate)
            
            if elapsed >= 1.0 {
                self.currentMetrics.fps = Double(self.frameCount) / elapsed
                self.frameCount = 0
                self.lastFPSUpdate = now
                
                self.logger.debug("Performance: \(String(format: "%.1f", self.currentMetrics.fps)) FPS, \(String(format: "%.1f", self.currentMetrics.totalLatency))ms Latency")
            }
        }
    }
    
    // MARK: - Types
    
    enum Phase {
        case capture, encode, network, decode, render
    }
}

// Float formatting extension for debug logs
extension Double {
    func format(as format: String) -> String {
        return String(format: "%\(format)", self)
    }
}
