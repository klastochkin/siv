import Foundation

/// Service for managing albums
class AlbumManager: ObservableObject {
    @Published var currentAlbum: Album?
    @Published var isLoading: Bool = false
    
    private let fileManager = FileManager.default
    
    /// Get the default album path
    var defaultAlbumPath: String {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let sivDirectory = appSupport.appendingPathComponent("SIV")
        
        // Create directory if it doesn't exist
        try? fileManager.createDirectory(at: sivDirectory, withIntermediateDirectories: true)
        
        return sivDirectory.appendingPathComponent("default.sivalb").path
    }
    
    /// Load the default album
    func loadDefaultAlbum() async {
        log("🔄 AlbumManager: Loading default album...")
        await MainActor.run {
            isLoading = true
        }
        
        let path = defaultAlbumPath
        log("📂 AlbumManager: Album path: \(path)")
        
        if fileManager.fileExists(atPath: path) {
            log("📖 AlbumManager: Album file exists, loading...")
            await loadAlbum(from: path)
        } else {
            log("🆕 AlbumManager: No album file, creating new...")
            // Create new default album
            let album = Album(name: "Default")
            await MainActor.run {
                currentAlbum = album
                log("✅ AlbumManager: Created new album")
            }
            await saveCurrentAlbum()
        }
        
        await MainActor.run {
            log("✅ AlbumManager: Album loaded with \(currentAlbum?.images.count ?? 0) images")
            isLoading = false
        }
    }
    
    /// Load album from file
    func loadAlbum(from path: String) async {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            log("❌ AlbumManager: Failed to read album file")
            return
        }
        
        guard let album = try? JSONDecoder().decode(Album.self, from: data) else {
            log("❌ AlbumManager: Failed to decode album JSON")
            return
        }
        
        log("✅ AlbumManager: Decoded album with \(album.images.count) images")
        
        await MainActor.run {
            currentAlbum = album
        }
    }
    
    /// Save current album
    func saveCurrentAlbum() async {
        guard let album = await MainActor.run(body: { currentAlbum }) else { return }
        
        let path = defaultAlbumPath
        
        guard let data = try? JSONEncoder().encode(album) else { return }
        try? data.write(to: URL(fileURLWithPath: path))
    }
    
    /// Save album to specific path
    func saveAlbum(_ album: Album, to path: String) async {
        guard let data = try? JSONEncoder().encode(album) else { return }
        try? data.write(to: URL(fileURLWithPath: path))
    }
    
    /// Add images to current album
    func addImages(_ paths: [String]) async {
        log("🎨 AlbumManager: Adding \(paths.count) images...")
        guard var album = await MainActor.run(body: { currentAlbum }) else {
            log("❌ AlbumManager: No current album!")
            return
        }
        
        log("📦 AlbumManager: Current album has \(album.images.count) images")
        
        for path in paths {
            let imageFile = ImageFile(path: path)
            album.addImage(imageFile)
            log("➕ AlbumManager: Added \(imageFile.fileName)")
        }
        
        log("📦 AlbumManager: Album now has \(album.images.count) images")
        
        let updatedAlbum = album
        await MainActor.run {
            log("💾 AlbumManager: Updating currentAlbum...")
            currentAlbum = updatedAlbum
            log("✅ AlbumManager: currentAlbum updated with \(currentAlbum?.images.count ?? 0) images")
        }
        
        await saveCurrentAlbum()
    }
    
    /// Insert an image at a specific index (used for undo of deletion).
    func insertImage(_ imageFile: ImageFile, at index: Int) async {
        guard var album = await MainActor.run(body: { currentAlbum }) else { return }
        album.insertImage(imageFile, at: index)
        let updatedAlbum = album
        await MainActor.run { currentAlbum = updatedAlbum }
        await saveCurrentAlbum()
    }

    /// Remove image from current album
    func removeImage(at index: Int) async {
        guard var album = await MainActor.run(body: { currentAlbum }) else { return }
        
        album.removeImage(at: index)
        
        let updatedAlbum = album
        await MainActor.run {
            currentAlbum = updatedAlbum
        }
        
        await saveCurrentAlbum()
    }
    
    /// Remove multiple images by index (handles reverse-order removal)
    func removeImages(at indices: Set<Int>) async {
        guard var album = await MainActor.run(body: { currentAlbum }) else { return }
        
        for index in indices.sorted(by: >) {
            guard index >= 0 && index < album.images.count else { continue }
            album.images.remove(at: index)
        }
        album.modified = Date()
        
        let updatedAlbum = album
        await MainActor.run {
            currentAlbum = updatedAlbum
        }
        
        await saveCurrentAlbum()
    }
    
    /// Remove image by ID
    func removeImage(id: UUID) async {
        guard var album = await MainActor.run(body: { currentAlbum }) else { return }
        
        album.removeImage(id: id)
        
        let updatedAlbum = album
        await MainActor.run {
            currentAlbum = updatedAlbum
        }
        
        await saveCurrentAlbum()
    }
    
    /// Remove all missing files
    func removeMissingFiles() async -> Int {
        guard var album = await MainActor.run(body: { currentAlbum }) else { return 0 }
        
        let removedCount = album.removeMissingFiles()
        
        let updatedAlbum = album
        await MainActor.run {
            currentAlbum = updatedAlbum
        }
        
        await saveCurrentAlbum()
        
        return removedCount
    }
    
    /// Get missing files
    var missingFiles: [ImageFile] {
        currentAlbum?.missingFiles ?? []
    }
    
    /// Check if album has missing files
    var hasMissingFiles: Bool {
        currentAlbum?.hasMissingFiles ?? false
    }
}
