import Foundation
import AppKit
import SwiftUI
import Combine

/// ViewModel for the Image View
@MainActor
class ImageViewModel: ObservableObject {
    @Published var currentImage: NSImage?
    @Published var currentImageFile: ImageFile?
    @Published var isLoading: Bool = false
    @Published var zoomState = ZoomState()
    
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
        isLoading = true
        
        currentLoadTask = Task {
            let image = await imageLoader.loadImage(from: imageFile.path)
            
            guard !Task.isCancelled else {
                isLoading = false
                return
            }
            
            currentImage = image
            isLoading = false
            
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
        guard let imageFile = currentImageFile else { return "" }
        
        var info = imageFile.fileName
        
        if let dimensions = imageFile.dimensions {
            info += " • \(Int(dimensions.width))×\(Int(dimensions.height))"
        }
        
        if let size = imageFile.fileSize {
            info += " • \(formatFileSize(size))"
        }
        
        info += " • \(zoomState.zoomPercentage)%"
        
        return info
    }
    
    /// Format file size for display
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
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
