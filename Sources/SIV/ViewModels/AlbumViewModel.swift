import Foundation
import SwiftUI
import Combine

/// View mode for album display
enum AlbumViewMode: String, CaseIterable {
    case thumbnails = "Thumbnails"
    case list = "List"
}

/// ViewModel for the Album View
@MainActor
class AlbumViewModel: ObservableObject {
    @Published var albumManager = AlbumManager()
    @Published var selectedImageIndex: Int?
    @Published var viewMode: AlbumViewMode = .list
    @Published var showMissingFilesDialog: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Forward albumManager changes to this view model (async to avoid publishing during view update)
        albumManager.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.objectWillChange.send()
            }
        }
        .store(in: &cancellables)
    }
    
    /// Initialize and load default album
    func initialize() async {
        print("🚀 AlbumViewModel: Initializing...")
        await albumManager.loadDefaultAlbum()
        print("✅ AlbumViewModel: Loaded album with \(images.count) images")
        
        // Check for missing files and show dialog if needed
        if albumManager.hasMissingFiles {
            showMissingFilesDialog = true
        }
    }
    
    /// Get current album
    var album: Album? {
        albumManager.currentAlbum
    }
    
    /// Get images in current album
    var images: [ImageFile] {
        album?.images ?? []
    }
    
    /// Add images to album
    func addImages(_ paths: [String]) async {
        print("📸 AlbumViewModel: Adding \(paths.count) images to album")
        await albumManager.addImages(paths)
        print("✅ AlbumViewModel: Album now has \(images.count) images")
        print("📋 AlbumViewModel: Images: \(images.map { $0.fileName }.joined(separator: ", "))")
    }
    
    /// Add image to album
    func addImage(_ path: String) async {
        await addImages([path])
    }
    
    /// Remove image at index
    func removeImage(at index: Int) async {
        await albumManager.removeImage(at: index)
        
        // Adjust selection if needed
        if let selected = selectedImageIndex {
            if selected == index {
                selectedImageIndex = nil
            } else if selected > index {
                selectedImageIndex = selected - 1
            }
        }
    }
    
    /// Remove missing files
    func removeMissingFiles() async {
        _ = await albumManager.removeMissingFiles()
        showMissingFilesDialog = false
    }
    
    /// Select next image
    func selectNextImage() {
        guard !images.isEmpty else { return }
        
        if let current = selectedImageIndex {
            selectedImageIndex = min(current + 1, images.count - 1)
        } else {
            selectedImageIndex = 0
        }
    }
    
    /// Select previous image
    func selectPreviousImage() {
        guard !images.isEmpty else { return }
        
        if let current = selectedImageIndex {
            selectedImageIndex = max(current - 1, 0)
        } else {
            selectedImageIndex = images.count - 1
        }
    }
    
    /// Get currently selected image
    var selectedImage: ImageFile? {
        guard let index = selectedImageIndex, index < images.count else {
            return nil
        }
        return images[index]
    }
    
    /// Select image at index
    func selectImage(at index: Int) {
        guard index >= 0 && index < images.count else { return }
        selectedImageIndex = index
    }
    
    /// Open file picker to add images
    func openFilePicker() {
        print("📂 AlbumViewModel: openFilePicker called")
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.jpeg, .png, .heic]
        
        print("📂 AlbumViewModel: Running modal panel...")
        let result = panel.runModal()
        print("📂 AlbumViewModel: Panel result: \(result == .OK ? "OK" : "Cancel")")
        
        if result == .OK {
            let paths = panel.urls.map { $0.path }
            print("📂 AlbumViewModel: Selected \(paths.count) files: \(paths)")
            Task {
                await addImages(paths)
                print("✅ AlbumViewModel: Images added to album")
            }
        }
    }
    
    /// Get missing files list
    var missingFiles: [ImageFile] {
        albumManager.missingFiles
    }
}
