import Foundation
import SwiftUI

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
    
    /// Initialize and load default album
    func initialize() async {
        await albumManager.loadDefaultAlbum()
        
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
        await albumManager.addImages(paths)
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
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.jpeg, .png, .heic]
        
        if panel.runModal() == .OK {
            let paths = panel.urls.map { $0.path }
            Task {
                await addImages(paths)
            }
        }
    }
    
    /// Get missing files list
    var missingFiles: [ImageFile] {
        albumManager.missingFiles
    }
}
