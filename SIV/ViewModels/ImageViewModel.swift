import SwiftUI
import Combine

/// View model managing the state and logic for image viewing
@MainActor
class ImageViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var currentImage: NSImage?
    @Published var currentFile: ImageFile?
    @Published var zoomState = ZoomState()
    @Published var isInfoBarVisible = true
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var effectiveScale: CGFloat = 1.0  // The actual display scale
    
    // MARK: - Private Properties
    
    private var availableImages: [ImageFile] = []
    private var currentIndex: Int = 0
    
    private let imageLoader = ImageLoader()
    private let fileNavigator = FileNavigator()
    private let imageCache = ImageCache()
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        setupNotifications()
    }
    
    // MARK: - Setup
    
    private func setupNotifications() {
        // Handle menu commands
        NotificationCenter.default.publisher(for: .zoomIn)
            .sink { [weak self] _ in self?.zoomIn() }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .zoomOut)
            .sink { [weak self] _ in self?.zoomOut() }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .actualSize)
            .sink { [weak self] _ in self?.setActualSize() }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .fitToWindow)
            .sink { [weak self] _ in self?.fitToWindow() }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .toggleInfoBar)
            .sink { [weak self] _ in self?.toggleInfoBar() }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .nextImage)
            .sink { [weak self] _ in self?.navigateNext() }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .previousImage)
            .sink { [weak self] _ in self?.navigatePrevious() }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .openFile)
            .sink { [weak self] notification in
                if let url = notification.userInfo?["url"] as? URL {
                    Task { await self?.openImage(at: url) }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Image Loading
    
    func openImage(at url: URL) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Load the image
            let image = try await imageLoader.loadImage(from: url)
            
            // Create ImageFile
            let imageFile = try ImageFile(url: url)
            
            // Get all images in the folder
            let images = try fileNavigator.getImagesInFolder(of: url)
            availableImages = images
            
            // Find current index
            if let index = fileNavigator.indexOf(imageFile, in: images) {
                currentIndex = index
            }
            
            // Update state
            currentImage = image
            currentFile = imageFile
            zoomState.reset()
            
            // Cache the image
            imageCache.set(image, for: url, size: imageFile.fileSize)
            
            // Preload adjacent images
            preloadAdjacentImages()
            
        } catch let error as ImageLoader.ImageLoadError {
            handleImageLoadError(error)
        } catch {
            errorMessage = "Failed to open image: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Navigation
    
    func navigateNext() {
        guard let current = currentFile else { return }
        guard let next = fileNavigator.nextImage(after: current, in: availableImages) else { return }
        
        Task {
            await loadImageFile(next)
        }
    }
    
    func navigatePrevious() {
        guard let current = currentFile else { return }
        guard let previous = fileNavigator.previousImage(before: current, in: availableImages) else { return }
        
        Task {
            await loadImageFile(previous)
        }
    }
    
    private func loadImageFile(_ imageFile: ImageFile) async {
        // Check cache first
        if let cachedImage = imageCache.get(imageFile.url) {
            currentImage = cachedImage
            currentFile = imageFile
            zoomState.reset()
            
            if let index = fileNavigator.indexOf(imageFile, in: availableImages) {
                currentIndex = index
            }
            
            preloadAdjacentImages()
            return
        }
        
        // Load from disk
        await openImage(at: imageFile.url)
    }
    
    private func preloadAdjacentImages() {
        guard let current = currentFile else { return }
        
        Task.detached(priority: .background) { [weak self] in
            guard let self = self else { return }
            
            // Preload next
            if let next = await self.fileNavigator.nextImage(after: current, in: self.availableImages) {
                if await self.imageCache.get(next.url) == nil {
                    if let image = try? await self.imageLoader.loadImage(from: next.url) {
                        await self.imageCache.set(image, for: next.url, size: next.fileSize)
                    }
                }
            }
            
            // Preload previous
            if let previous = await self.fileNavigator.previousImage(before: current, in: self.availableImages) {
                if await self.imageCache.get(previous.url) == nil {
                    if let image = try? await self.imageLoader.loadImage(from: previous.url) {
                        await self.imageCache.set(image, for: previous.url, size: previous.fileSize)
                    }
                }
            }
        }
    }
    
    // MARK: - Zoom Controls
    
    func zoomIn() {
        // Don't zoom if already at maximum
        guard zoomState.scale < ZoomState.maxScale else { return }
        
        zoomState.scale *= 1.2
        zoomState.clampScale()
        zoomState.mode = .custom
    }
    
    func zoomOut() {
        // Don't zoom if already at minimum
        guard zoomState.scale > ZoomState.minScale else { return }
        
        zoomState.scale /= 1.2
        zoomState.clampScale()
        zoomState.mode = .custom
    }
    
    func setActualSize() {
        zoomState.scale = 1.0
        zoomState.offset = .zero
        zoomState.mode = .actualSize
    }
    
    func fitToWindow() {
        zoomState.reset()
    }
    
    func zoom(by factor: CGFloat, around center: CGPoint) {
        zoomState.zoom(by: factor, around: center)
        zoomState.mode = .custom
    }
    
    func pan(by delta: CGSize) {
        zoomState.offset.width += delta.width
        zoomState.offset.height += delta.height
    }
    
    // MARK: - UI Controls
    
    func toggleInfoBar() {
        isInfoBarVisible.toggle()
    }
    
    // MARK: - Info Formatting
    
    var imageInfo: String {
        guard let file = currentFile else { return "" }
        
        let dimensions: String
        if let size = file.dimensions {
            dimensions = "\(Int(size.width))×\(Int(size.height))"
        } else if let image = currentImage {
            dimensions = "\(Int(image.size.width))×\(Int(image.size.height))"
        } else {
            dimensions = "Unknown"
        }
        
        let fileSize = ByteCountFormatter.string(fromByteCount: file.fileSize, countStyle: .file)
        
        // Use effective scale for accurate percentage
        let zoomPercentage = Int(effectiveScale * 100)
        let zoom = "\(zoomPercentage)%"
        
        return "\(file.filename)  •  \(dimensions)  •  \(fileSize)  •  \(zoom)"
    }
    
    // MARK: - Error Handling
    
    private func handleImageLoadError(_ error: ImageLoader.ImageLoadError) {
        switch error {
        case .fileNotFound:
            errorMessage = "Image file no longer exists"
        case .unsupportedFormat:
            errorMessage = "Image format not supported"
        case .corruptedFile:
            errorMessage = "Unable to open image: file may be corrupted"
        case .permissionDenied:
            errorMessage = "No permission to access file"
        case .unknownError(let message):
            errorMessage = "Error: \(message)"
        }
    }
}

