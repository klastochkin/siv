import SwiftUI
import AppKit

// View modifier to handle scroll wheel events
struct ScrollWheelModifier: ViewModifier {
    let action: (NSEvent) -> Void
    
    func body(content: Content) -> some View {
        content.background(
            ScrollWheelView(action: action)
        )
    }
}

struct ScrollWheelView: NSViewRepresentable {
    let action: (NSEvent) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = ScrollableView()
        view.scrollAction = action
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
    
    class ScrollableView: NSView {
        var scrollAction: ((NSEvent) -> Void)?
        
        override func scrollWheel(with event: NSEvent) {
            scrollAction?(event)
        }
    }
}

extension View {
    func onScrollWheel(perform action: @escaping (NSEvent) -> Void) -> some View {
        modifier(ScrollWheelModifier(action: action))
    }
}

/// Zoomable and pannable image display canvas
struct ImageCanvas: View {
    @ObservedObject var viewModel: ImageViewModel
    
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var magnificationScale: CGFloat = 1.0
    @State private var isMagnifying = false
    @State private var magnificationAnchor: CGPoint = .zero
    @State private var lastDisplayScale: CGFloat = 1.0
    @State private var imageDisplaySize: CGSize = .zero
    @State private var windowSize: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image = viewModel.currentImage {
                    let baseScale = effectiveScale(for: image, in: geometry.size)
                    // During magnification, apply both base scale and gesture scale
                    let displayScale = isMagnifying ? baseScale * magnificationScale : baseScale
                    let imageSize = image.size
                    let displaySize = CGSize(
                        width: imageSize.width * displayScale,
                        height: imageSize.height * displayScale
                    )
                    
                    // Track the actual displayed scale and size for gesture handling
                    let _ = {
                        lastDisplayScale = displayScale
                        imageDisplaySize = displaySize
                        windowSize = geometry.size
                    }()
                    
                    Image(nsImage: image)
                        .resizable()
                        .frame(width: displaySize.width, height: displaySize.height)
                        .offset(effectiveOffset)
                        .simultaneousGesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    handleMagnificationChanged(value, in: geometry)
                                }
                                .onEnded { value in
                                    handleMagnificationEnded(value, in: geometry)
                                }
                        )
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 5)
                                .onChanged { value in
                                    handleDragChanged(value)
                                }
                                .onEnded { value in
                                    handleDragEnded(value)
                                }
                        )
                        .onScrollWheel { event in
                            handleScrollWheel(event, in: geometry)
                        }
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(_):
                                // Could show cursor info here
                                break
                            case .ended:
                                break
                            }
                        }
                        .onAppear {
                            // Update effective scale for info display
                            viewModel.effectiveScale = displayScale
                        }
                        .onChange(of: geometry.size) { _ in
                            viewModel.effectiveScale = displayScale
                        }
                        .onChange(of: viewModel.zoomState.scale) { _ in
                            viewModel.effectiveScale = displayScale
                        }
                        .onChange(of: viewModel.zoomState.mode) { _ in
                            viewModel.effectiveScale = displayScale
                        }
                        .onChange(of: viewModel.currentImage) { _ in
                            // Reset to fit window when new image loads
                            viewModel.effectiveScale = displayScale
                            dragOffset = .zero
                        }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .onAppear {
            // Reset drag state when image changes
            dragOffset = .zero
        }
    }
    
    // MARK: - Computed Properties
    
    private func effectiveScale(for image: NSImage, in containerSize: CGSize) -> CGFloat {
        let scale: CGFloat
        if viewModel.zoomState.mode == .fitToWindow {
            scale = calculateFitToWindowScale(for: image, in: containerSize)
        } else {
            scale = viewModel.zoomState.scale
        }
        
        // Enforce zoom limits: 10% to 1600%
        return min(max(scale, ZoomState.minScale), ZoomState.maxScale)
    }
    
    private var effectiveOffset: CGSize {
        return CGSize(
            width: viewModel.zoomState.offset.width + dragOffset.width,
            height: viewModel.zoomState.offset.height + dragOffset.height
        )
    }
    
    // MARK: - Calculations
    
    private func calculateFitToWindowScale(for image: NSImage, in containerSize: CGSize) -> CGFloat {
        let imageSize = image.size
        let padding: CGFloat = 40 // 20px on each side
        let availableWidth = containerSize.width - padding
        let availableHeight = containerSize.height - padding
        
        let widthScale = availableWidth / imageSize.width
        let heightScale = availableHeight / imageSize.height
        
        // Allow scaling up to fit window, remove the min(..., 1.0) restriction
        return min(widthScale, heightScale)
    }
    
    // MARK: - Gesture Handlers
    
    private func handleMagnificationChanged(_ value: MagnificationGesture.Value, in geometry: GeometryProxy) {
        // Apply magnification directly to state for instant feedback
        if !isMagnifying {
            // First time - use center of visible area as zoom anchor
            isMagnifying = true
            // Zoom around the center of the window for stable, predictable behavior
            magnificationAnchor = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        
        // Make zoom less sensitive by dampening the magnitude
        let dampening: CGFloat = 0.2
        magnificationScale = 1.0 + (value.magnitude - 1.0) * dampening
    }
    
    private func handleMagnificationEnded(_ value: MagnificationGesture.Value, in geometry: GeometryProxy) {
        // Calculate the zoom change
        let dampening: CGFloat = 0.2
        let adjustedMagnitude = 1.0 + (value.magnitude - 1.0) * dampening
        
        // Get the current effective scale before we change mode
        guard let image = viewModel.currentImage else {
            isMagnifying = false
            magnificationScale = 1.0
            dragOffset = .zero
            return
        }
        
        let currentEffectiveScale = effectiveScale(for: image, in: geometry.size)
        
        // Calculate new scale based on current effective scale (not zoomState.scale)
        var newScale = currentEffectiveScale * adjustedMagnitude
        newScale = min(max(newScale, ZoomState.minScale), ZoomState.maxScale)
        
        // Apply the scale change
        viewModel.zoomState.scale = newScale
        viewModel.zoomState.mode = .custom
        
        // If there was any drag during magnification, apply it
        if isDragging {
            viewModel.zoomState.offset.width += dragOffset.width
            viewModel.zoomState.offset.height += dragOffset.height
            isDragging = false
        }
        
        // Reset magnification state
        isMagnifying = false
        magnificationScale = 1.0
        dragOffset = .zero
    }
    
    private func handleScrollWheel(_ event: NSEvent, in geometry: GeometryProxy) {
        // Scroll wheel zoom with reasonable sensitivity
        let zoomSensitivity: CGFloat = 0.001
        let zoomDelta = event.scrollingDeltaY * zoomSensitivity
        
        // Calculate zoom factor (small increments)
        let zoomFactor = 1.0 + zoomDelta
        
        // Check if we're at limits to prevent unnecessary operations
        let currentScale = viewModel.zoomState.scale
        if (zoomFactor > 1.0 && currentScale >= ZoomState.maxScale) ||
           (zoomFactor < 1.0 && currentScale <= ZoomState.minScale) {
            // At limit, ignore zoom request
            return
        }
        
        let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        viewModel.zoom(by: zoomFactor, around: center)
    }
    
    private func handleDragChanged(_ value: DragGesture.Value) {
        // Always allow panning - let user move image freely
        isDragging = true
        dragOffset = value.translation
    }
    
    private func handleDragEnded(_ value: DragGesture.Value) {
        if isDragging {
            viewModel.pan(by: dragOffset)
            dragOffset = .zero
            isDragging = false
        }
    }
}

#Preview {
    ImageCanvas(viewModel: ImageViewModel())
}

