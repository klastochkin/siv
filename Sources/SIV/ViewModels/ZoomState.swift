import Foundation
import CoreGraphics
import SwiftUI

/// Manages zoom and pan state for the image viewer
/// This is a ViewModel (not a Model) because it's ObservableObject with @Published properties
class ZoomState: ObservableObject {
    // MARK: - Published Properties
    @Published var scale: CGFloat = 1.0
    @Published var offset: CGSize = .zero
    
    // MARK: - Constants
    static let minZoom: CGFloat = 0.1  // 10%
    static let maxZoom: CGFloat = 16.0 // 1600%
    static let scrollSensitivity: CGFloat = 0.001
    static let pinchDampening: CGFloat = 0.2
    static let panStep: CGFloat = 50.0
    
    // MARK: - Properties
    var imageSize: CGSize = .zero
    var viewSize: CGSize = .zero
    
    // MARK: - Computed Properties
    
    /// Current zoom level as percentage
    var zoomPercentage: Int {
        Int(scale * 100)
    }
    
    /// Actual display size of the image
    var displaySize: CGSize {
        CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }
    
    /// Check if panning is enabled (image is larger than view)
    var canPan: Bool {
        displaySize.width > viewSize.width || displaySize.height > viewSize.height
    }
    
    // MARK: - Zoom Methods
    
    /// Set zoom to fit window
    func fitToWindow() {
        guard imageSize.width > 0 && imageSize.height > 0 && viewSize.width > 0 && viewSize.height > 0 else { return }
        
        let scaleX = viewSize.width / imageSize.width
        let scaleY = viewSize.height / imageSize.height
        scale = min(scaleX, scaleY)
        
        // Clamp to zoom limits
        scale = max(Self.minZoom, min(Self.maxZoom, scale))
        
        // Reset offset when fitting
        offset = .zero
    }
    
    /// Set zoom to actual size (100%)
    func actualSize() {
        scale = 1.0
        offset = .zero
    }
    
    /// Zoom in
    func zoomIn() {
        scale = min(scale * 1.25, Self.maxZoom)
        clampOffset()
    }
    
    /// Zoom out
    func zoomOut() {
        scale = max(scale / 1.25, Self.minZoom)
        clampOffset()
    }
    
    /// Apply scroll wheel zoom
    func applyScrollZoom(delta: CGFloat, at point: CGPoint) {
        let oldScale = scale
        let zoomFactor = 1.0 + (delta * Self.scrollSensitivity)
        scale = max(Self.minZoom, min(Self.maxZoom, scale * zoomFactor))
        
        // Adjust offset to zoom towards the cursor position
        if scale != oldScale {
            let scaleRatio = scale / oldScale - 1.0
            offset.width -= (point.x - viewSize.width / 2) * scaleRatio
            offset.height -= (point.y - viewSize.height / 2) * scaleRatio
            clampOffset()
        }
    }
    
    /// Apply pinch gesture zoom
    func applyPinchZoom(magnification: CGFloat) {
        let dampened = 1.0 + (magnification - 1.0) * Self.pinchDampening
        scale = max(Self.minZoom, min(Self.maxZoom, scale * dampened))
        clampOffset()
    }
    
    // MARK: - Pan Methods
    
    /// Pan by a delta
    func pan(by delta: CGSize) {
        guard canPan else { return }
        offset.width += delta.width
        offset.height += delta.height
        clampOffset()
    }
    
    /// Pan up
    func panUp() {
        pan(by: CGSize(width: 0, height: Self.panStep))
    }
    
    /// Pan down
    func panDown() {
        pan(by: CGSize(width: 0, height: -Self.panStep))
    }
    
    /// Pan left
    func panLeft() {
        pan(by: CGSize(width: Self.panStep, height: 0))
    }
    
    /// Pan right
    func panRight() {
        pan(by: CGSize(width: -Self.panStep, height: 0))
    }
    
    // MARK: - Helper Methods
    
    /// Clamp offset to valid range
private func clampOffset() {
        guard canPan else {
            offset = .zero
            return
        }
        
        let maxOffsetX = max(0, (displaySize.width - viewSize.width) / 2)
        let maxOffsetY = max(0, (displaySize.height - viewSize.height) / 2)
        
        offset.width = max(-maxOffsetX, min(maxOffsetX, offset.width))
        offset.height = max(-maxOffsetY, min(maxOffsetY, offset.height))
    }
    
    /// Reset to default state
    func reset(imageSize: CGSize, viewSize: CGSize) {
        self.imageSize = imageSize
        self.viewSize = viewSize
        fitToWindow()
    }

    /// Upgrade the reference image size when a higher-quality version of the same
    /// image arrives. Adjusts scale proportionally so the visible region stays identical.
    func upgradeImageSize(to newSize: CGSize) {
        guard imageSize.width > 0, newSize.width > 0 else {
            imageSize = newSize
            return
        }
        let ratio = newSize.width / imageSize.width
        imageSize = newSize
        scale = max(Self.minZoom, min(Self.maxZoom, scale / ratio))
        clampOffset()
    }
    
    /// Update view size
    func updateViewSize(_ size: CGSize) {
        viewSize = size
        clampOffset()
    }
}
