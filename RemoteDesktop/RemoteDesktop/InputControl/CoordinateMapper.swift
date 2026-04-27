//
//  CoordinateMapper.swift
//  RemoteDesktop
//
//  Maps coordinates between client and host display resolutions
//

import Foundation
import CoreGraphics
import os.log

/// Helper class to map coordinates between different screen resolutions
class CoordinateMapper {
    private let logger = Logger(subsystem: "com.gupt", category: "CoordinateMapper")
    
    private var hostWidth: CGFloat
    private var hostHeight: CGFloat
    
    /// Initialize with the host's resolution
    init(hostWidth: Int, hostHeight: Int) {
        self.hostWidth = CGFloat(hostWidth)
        self.hostHeight = CGFloat(hostHeight)
    }
    
    /// Map normalized (0.0 to 1.0) coordinates to absolute host coordinates
    /// - Parameter normalizedPoint: Point from 0 to 1
    /// - Returns: Absolute point on host screen
    func mapToHost(normalizedPoint: CGPoint) -> CGPoint {
        let x = normalizedPoint.x * hostWidth
        let y = normalizedPoint.y * hostHeight
        
        // Ensure coordinates are within bounds
        let clampedX = max(0, min(hostWidth - 1, x))
        let clampedY = max(0, min(hostHeight - 1, y))
        
        return CGPoint(x: clampedX, y: clampedY)
    }
    
    /// Map a point from a local view to a normalized point
    /// - Parameters:
    ///   - point: Local coordinates in the view
    ///   - viewBounds: Bounds of the local view
    /// - Returns: Normalized (0-1) coordinates
    static func normalize(point: CGPoint, in viewBounds: CGRect) -> CGPoint {
        let x = point.x / viewBounds.width
        let y = point.y / viewBounds.height
        
        // Clamping to 0.0 - 1.0
        let clampedX = max(0.0, min(1.0, x))
        let clampedY = max(0.0, min(1.0, y))
        
        return CGPoint(x: clampedX, y: clampedY)
    }
    
    /// Update host resolution (e.g. on display change)
    func updateHostResolution(width: Int, height: Int) {
        self.hostWidth = CGFloat(width)
        self.hostHeight = CGFloat(height)
        self.logger.info("Host resolution updated to \(width)x\(height)")
    }
}
