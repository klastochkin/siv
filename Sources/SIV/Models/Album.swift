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
    
    // Custom coding keys to support legacy "entries" format
    enum CodingKeys: String, CodingKey {
        case name
        case images
        case entries // Legacy format
        case created
        case modified
    }
    
    // Custom decoder to handle both "images" and "entries"
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Default"
        created = try container.decodeIfPresent(Date.self, forKey: .created) ?? Date()
        modified = try container.decodeIfPresent(Date.self, forKey: .modified) ?? Date()
        
        // Try to decode from "images" first, then fall back to "entries"
        if let imgs = try? container.decode([ImageFile].self, forKey: .images) {
            images = imgs
        } else if let entries = try? container.decode([ImageFile].self, forKey: .entries) {
            images = entries
        } else {
            images = []
        }
    }
    
    // Custom encoder to always use "images"
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(images, forKey: .images)
        try container.encode(created, forKey: .created)
        try container.encode(modified, forKey: .modified)
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
