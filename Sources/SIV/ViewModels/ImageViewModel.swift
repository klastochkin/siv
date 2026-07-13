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
    private var prefetchTasks: [Task<Void, Never>] = []
    private var zoomStateCancellable: AnyCancellable?
    
    init() {
        // Forward zoomState changes to trigger view updates
        zoomStateCancellable = zoomState.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }
    
    /// Load an image from a file — two-stage progressive load:
    ///   1. If full quality is cached → show instantly.
    ///   2. Otherwise show 960 px preview first, then upgrade to full quality
    ///      in the background. Zoom is initialised on stage 1 and adjusted
    ///      proportionally when stage 2 arrives so the visible region is preserved.
    func loadImage(from imageFile: ImageFile) {
        currentLoadTask?.cancel()

        currentImageFile = imageFile
        cachedInfoBase = ""
        isLoading = true
        let requestedAt = Date()
        log("⏳ ImageViewModel: Start rendering \(imageFile.fileName)")

        currentLoadTask = Task {
            let path = imageFile.path
            let taskStartedMs = Int(Date().timeIntervalSince(requestedAt) * 1000)
            log("⏱️ ImageViewModel: Task began after \(taskStartedMs)ms \(imageFile.fileName)")

            // ── Fast path: full quality already in cache (~15 ms) ───────────
            let cached = await imageLoader.isFullyCached(path: path)
            let cacheCheckMs = Int(Date().timeIntervalSince(requestedAt) * 1000)
            log("⏱️ ImageViewModel: cache check (\(cached ? "HIT" : "miss")) after \(cacheCheckMs)ms \(imageFile.fileName)")
            if cached {
                guard let full = await imageLoader.loadImage(from: path),
                      !Task.isCancelled else {
                    isLoading = false
                    return
                }
                currentImage = full
                isLoading = false
                log("✅ ImageViewModel: Rendered from cache \(imageFile.fileName)")
                zoomState.reset(imageSize: full.size, viewSize: zoomState.viewSize)
                await buildInfoBase(path: path)
                return
            }

            // ── Slow path: start preview + full in parallel ──────────────────
            async let previewLoad = imageLoader.loadPreview(from: path)
            async let fullLoad    = imageLoader.loadImage(from: path)

            // Stage 1 — show preview (~50–80 ms estimated)
            if let preview = await previewLoad, !Task.isCancelled {
                currentImage = preview
                isLoading = false
                log("⚡ ImageViewModel: Showing preview for \(imageFile.fileName)")
                zoomState.reset(imageSize: preview.size, viewSize: zoomState.viewSize)
            }

            // Stage 2 — upgrade to full quality (~240 ms)
            if let full = await fullLoad, !Task.isCancelled {
                zoomState.upgradeImageSize(to: full.size)
                currentImage = full
                isLoading = false
                log("✅ ImageViewModel: Upgraded to full quality \(imageFile.fileName)")
            }

            await buildInfoBase(path: path)
        }
    }

    /// Start background Tier-2 prefetch for a list of images.
    /// Uses .utility priority so the OS schedules prefetch tasks promptly
    /// even while foreground decode work is running.
    func prefetchImages(_ files: [ImageFile]) {
        // Cancel the previous batch so rapid navigation doesn't pile up stale prefetches.
        prefetchTasks.forEach { $0.cancel() }
        prefetchTasks.removeAll(keepingCapacity: true)

        let loader = imageLoader
        for file in files {
            let task = Task.detached(priority: .utility) {
                guard !Task.isCancelled else { return }
                await loader.prefetch(path: file.path)
            }
            prefetchTasks.append(task)
        }
    }

    private func buildInfoBase(path: String) async {
        let info = await Task.detached(priority: .utility) {
            var result = URL(fileURLWithPath: path).lastPathComponent
            let url = URL(fileURLWithPath: path) as CFURL
            if let source = CGImageSourceCreateWithURL(url, nil),
               let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
               let w = props[kCGImagePropertyPixelWidth] as? CGFloat,
               let h = props[kCGImagePropertyPixelHeight] as? CGFloat {
                result += " • \(Int(w))×\(Int(h))"
            }
            if let attrs = try? FileManager.default.attributesOfItem(atPath: path),
               let size = attrs[.size] as? Int64 {
                let fmt = ByteCountFormatter()
                fmt.allowedUnits = [.useKB, .useMB, .useGB]
                fmt.countStyle = .file
                result += " • \(fmt.string(fromByteCount: size))"
            }
            return result
        }.value
        cachedInfoBase = info
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
