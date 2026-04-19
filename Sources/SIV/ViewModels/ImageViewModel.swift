import Foundation
import AppKit
import SwiftUI
import Combine
import ImageIO

/// ViewModel for the Image View
@MainActor
class ImageViewModel: ObservableObject {
    @Published var currentImage: NSImage?
    @Published var currentImageFile: ImageFile?
    @Published var isLoading: Bool = false
    @Published var zoomState = ZoomState()

    /// Static part of the info bar (filename, dimensions, size) — computed once per image load.
    private var cachedInfoBase = ""
    
    private let imageLoader = ImageLoader()
    private var currentLoadTask: Task<Void, Never>?
    private var zoomStateCancellable: AnyCancellable?
    
    init() {
        // Forward zoomState changes to trigger view updates
        zoomStateCancellable = zoomState.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }
    
    /// Load an image from a file
    func loadImage(from imageFile: ImageFile) {
        // Cancel previous loading task
        currentLoadTask?.cancel()
        
        currentImageFile = imageFile
        cachedInfoBase = ""
        isLoading = true
        log("⏳ ImageViewModel: Start rendering \(imageFile.fileName)")
        
        currentLoadTask = Task {
            let image = await imageLoader.loadImage(from: imageFile.path)
            
            guard !Task.isCancelled else {
                isLoading = false
                log("🚫 ImageViewModel: Rendering cancelled for \(imageFile.fileName)")
                return
            }
            
            currentImage = image
            isLoading = false
            log("✅ ImageViewModel: Finished rendering \(imageFile.fileName)")

            // Build the static portion of the info bar off the render path.
            // These disk reads happen once per image load, not on every zoom/pan frame.
            let path = imageFile.path
            let infoBase = await Task.detached(priority: .userInitiated) {
                var info = URL(fileURLWithPath: path).lastPathComponent
                let url = URL(fileURLWithPath: path) as CFURL
                if let source = CGImageSourceCreateWithURL(url, nil),
                   let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                   let w = props[kCGImagePropertyPixelWidth] as? CGFloat,
                   let h = props[kCGImagePropertyPixelHeight] as? CGFloat {
                    info += " • \(Int(w))×\(Int(h))"
                }
                if let attrs = try? FileManager.default.attributesOfItem(atPath: path),
                   let size = attrs[.size] as? Int64 {
                    let formatter = ByteCountFormatter()
                    formatter.allowedUnits = [.useKB, .useMB, .useGB]
                    formatter.countStyle = .file
                    info += " • \(formatter.string(fromByteCount: size))"
                }
                return info
            }.value
            cachedInfoBase = infoBase

            // Reset zoom state for new image
            if let image = image {
                let imageSize = image.size
                zoomState.reset(imageSize: imageSize, viewSize: zoomState.viewSize)
            }
        }
    }
    
    /// Open an image file via file picker
    func openImageFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.jpeg, .png, .heic]
        
        if panel.runModal() == .OK, let url = panel.url {
            let imageFile = ImageFile(path: url.path)
            loadImage(from: imageFile)
        }
    }
    
    /// Clear current image
    func clearImage() {
        currentLoadTask?.cancel()
        currentImage = nil
        currentImageFile = nil
        isLoading = false
    }
    
    /// Get image info for display
    var imageInfo: String {
        guard !cachedInfoBase.isEmpty else { return "" }
        return "\(cachedInfoBase) • \(zoomState.zoomPercentage)%"
    }
    
    /// Update view size (for zoom calculations)
    func updateViewSize(_ size: CGSize) {
        zoomState.updateViewSize(size)
        // Don't auto-fit here - let the user control zoom
        // fitToWindow() is called explicitly when image loads
    }
    
    // MARK: - Keyboard Actions
    
    func fitToWindow() {
        zoomState.fitToWindow()
        objectWillChange.send() // Trigger view update
    }
    
    func actualSize() {
        zoomState.actualSize()
        // objectWillChange.send() // Trigger view update
        
        // Display message box with current data
        // let alert = NSAlert()
        // alert.messageText = "Image Data Available"
        
        // var infoText = "Current Image Information:\n\n"
        
        // if let imageFile = currentImageFile {
        //     infoText += "File: \(imageFile.fileName)\n"
        //     infoText += "Path: \(imageFile.path)\n"
            
        //     if let dimensions = imageFile.dimensions {
        //         infoText += "Dimensions: \(Int(dimensions.width))×\(Int(dimensions.height)) px\n"
        //     }
            
        //     if let size = imageFile.fileSize {
        //         infoText += "File Size: \(formatFileSize(size))\n"
        //     }
        // } else {
        //     infoText += "No image file loaded\n"
        // }
        
        // if let image = currentImage {
        //     let imageSize = image.size
        //     infoText += "\nImage Size: \(Int(imageSize.width))×\(Int(imageSize.height)) px\n"
        // } else {
        //     infoText += "\nNo image loaded\n"
        // }
        
        // infoText += "\nZoom State:\n"
        // infoText += "Zoom: \(zoomState.zoomPercentage)%\n"
        // infoText += "View Size: \(Int(zoomState.viewSize.width))×\(Int(zoomState.viewSize.height))\n"
        // infoText += "Image Size: \(Int(zoomState.imageSize.width))×\(Int(zoomState.imageSize.height))\n"
        
        // alert.informativeText = infoText
        // alert.alertStyle = .informational
        // alert.addButton(withTitle: "OK")
        
        // alert.runModal()
    }
    
    func zoomIn() {
        zoomState.zoomIn()
        // objectWillChange.send() // Trigger view update
    }
    
    func zoomOut() {
        zoomState.zoomOut()
        // objectWillChange.send() // Trigger view update
    }
    
    func panLeft() {
        zoomState.panLeft()
        // objectWillChange.send() // Trigger view update
    }
    
    func panRight() {
        zoomState.panRight()
        // objectWillChange.send() // Trigger view update
    }
    
    func panUp() {
        zoomState.panUp()
        // objectWillChange.send() // Trigger view update
    }
    
    func panDown() {
        zoomState.panDown()
        // objectWillChange.send() // Trigger view update
    }
}
