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
        await MainActor.run {
            isLoading = true
        }
        
        let path = defaultAlbumPath
        
        if fileManager.fileExists(atPath: path) {
            await loadAlbum(from: path)
        } else {
            // Create new default album
            let album = Album(name: "Default")
            await MainActor.run {
                currentAlbum = album
            }
            await saveCurrentAlbum()
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    /// Load album from file
    func loadAlbum(from path: String) async {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let album = try? JSONDecoder().decode(Album.self, from: data) else {
            return
        }
        
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
        guard var album = await MainActor.run(body: { currentAlbum }) else { return }
        
        for path in paths {
            let imageFile = ImageFile(path: path)
            album.addImage(imageFile)
        }
        
        let updatedAlbum = album
        await MainActor.run {
            currentAlbum = updatedAlbum
        }
        
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
