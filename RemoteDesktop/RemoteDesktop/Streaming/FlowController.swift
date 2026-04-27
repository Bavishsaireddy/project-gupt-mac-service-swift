//
//  FlowController.swift
//  RemoteDesktop
//
//  Monitors network conditions and adjusts bitrate/FPS accordingly
//

import Foundation
import os.log

/// Delegate for flow control updates
protocol FlowControllerDelegate: AnyObject {
    func flowController(_ controller: FlowController, didUpdateBitrate bitrate: Int)
    func flowController(_ controller: FlowController, didUpdateFrameRate fps: Int)
}

/// Manages network congestion and quality adaptation
class FlowController {
    private let logger = Logger(subsystem: "com.gupt", category: "FlowController")
    
    weak var delegate: FlowControllerDelegate?
    
    private var currentBitrate: Int = 2_500_000 // 2.5 Mbps
    private var currentFPS: Int = 30
    
    private var rttHistory: [Double] = []
    private var lossHistory: [Bool] = []
    
    private let queue = DispatchQueue(label: "com.gupt.flowcontroller", qos: .utility)
    
    // MARK: - Metrics Update
    
    /// Reports current RTT
    func reportRTT(_ rtt: Double) {
        queue.async {
            self.rttHistory.append(rtt)
            if self.rttHistory.count > 20 {
                self.rttHistory.removeFirst()
            }
            
            self.analyzeConditions()
        }
    }
    
    /// Reports packet loss
    func reportPacketLoss(_ lost: Bool) {
        queue.async {
            self.lossHistory.append(lost)
            if self.lossHistory.count > 50 {
                self.lossHistory.removeFirst()
            }
            
            self.analyzeConditions()
        }
    }
    
    // MARK: - Analysis
    
    private func analyzeConditions() {
        // Simple AIMD-like algorithm (Additive Increase, Multiplicative Decrease)
        
        let avgRTT = rttHistory.reduce(0, +) / Double(max(1, rttHistory.count))
        let lossCount = lossHistory.filter({ $0 }).count
        let lossRate = Double(lossCount) / Double(max(1, lossHistory.count))
        
        var targetBitrate = currentBitrate
        var targetFPS = currentFPS
        
        if lossRate > 0.05 || avgRTT > 200 {
            // Congestion! Decrease bitrate
            targetBitrate = Int(Double(currentBitrate) * 0.8)
            targetFPS = max(15, currentFPS - 5)
            self.logger.warning("Congestion detected (RTT: \(avgRTT)ms, Loss: \(lossRate*100)%). Decreasing targets.")
        } else if lossRate < 0.01 && avgRTT < 100 {
            // Stable. Increase bitrate
            targetBitrate = currentBitrate + 250_000
            targetFPS = min(60, currentFPS + 5)
        }
        
        // Clamp values
        targetBitrate = max(500_000, min(10_000_000, targetBitrate))
        
        if targetBitrate != currentBitrate {
            currentBitrate = targetBitrate
            delegate?.flowController(self, didUpdateBitrate: targetBitrate)
        }
        
        if targetFPS != currentFPS {
            currentFPS = targetFPS
            delegate?.flowController(self, didUpdateFrameRate: targetFPS)
        }
    }
}
