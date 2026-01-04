import Foundation
import CoreGraphics

/// Represents the current zoom and pan state of the image viewer
struct ZoomState {
    var scale: CGFloat = 1.0       // Current zoom scale (0.1 to 16.0)
    var offset: CGSize = .zero     // Pan offset when zoomed in
    var mode: ZoomMode = .fitToWindow  // Default: always fit to window initially
    
    /// Zoom mode determines how the image is displayed
    enum ZoomMode {
        case fitToWindow    // Scale to fit window, maintain aspect ratio
        case actualSize     // Display at 100% (1:1 pixel ratio)
        case custom         // User-controlled zoom level
    }
    
    /// Minimum zoom level (10%)
    static let minScale: CGFloat = 0.1
    
    /// Maximum zoom level (1600%)
    static let maxScale: CGFloat = 16.0
    
    /// Clamps the scale to valid range
    mutating func clampScale() {
        scale = min(max(scale, ZoomState.minScale), ZoomState.maxScale)
    }
    
    /// Resets to default state
    mutating func reset() {
        scale = 1.0
        offset = .zero
        mode = .fitToWindow
    }
    
    /// Applies zoom centered on a point
    mutating func zoom(by factor: CGFloat, around center: CGPoint) {
        let oldScale = scale
        scale *= factor
        clampScale()
        
        // Adjust offset to zoom around the center point
        let scaleDelta = scale - oldScale
        offset.width -= center.x * scaleDelta
        offset.height -= center.y * scaleDelta
    }
    
    /// Get zoom percentage for display
    var percentage: Int {
        return Int(scale * 100)
    }
}

