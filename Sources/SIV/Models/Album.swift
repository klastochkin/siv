import Foundation

/// Represents a picture album
struct Album: Codable {
    var name: String
    var images: [ImageFile]
    var created: Date
    var modified: Date
    
    init(name: String) {
        self.name = name
        self.images = []
        self.created = Date()
        self.modified = Date()
    }
    
    /// Add an image to the album
    mutating func addImage(_ imageFile: ImageFile) {
        // Check if image already exists
        if !images.contains(where: { $0.path == imageFile.path }) {
            images.append(imageFile)
            modified = Date()
        }
    }
    
    /// Remove an image from the album
    mutating func removeImage(at index: Int) {
        guard index >= 0 && index < images.count else { return }
        images.remove(at: index)
        modified = Date()
    }
    
    /// Remove image by ID
    mutating func removeImage(id: UUID) {
        images.removeAll { $0.id == id }
        modified = Date()
    }
    
    /// Remove all missing files
    mutating func removeMissingFiles() -> Int {
        let beforeCount = images.count
        images.removeAll { !$0.exists }
        modified = Date()
        return beforeCount - images.count
    }
    
    /// Get list of missing files
    var missingFiles: [ImageFile] {
        images.filter { !$0.exists }
    }
    
    /// Check if album has missing files
    var hasMissingFiles: Bool {
        images.contains { !$0.exists }
    }
}
