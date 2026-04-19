import Foundation
import AppKit

/// Represents an image file in the album
struct ImageFile: Codable, Identifiable, Equatable {
    let id: UUID
    let path: String
    var lastModified: Date
    
    init(path: String) {
        self.id = UUID()
        self.path = path
        self.lastModified = Date()
    }
    
    init(id: UUID, path: String, lastModified: Date) {
        self.id = id
        self.path = path
        self.lastModified = lastModified
    }
    
    // Custom decoder to handle legacy format where "id" was a string (path)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try to decode id as UUID first, then fall back to generating one
        if let uuid = try? container.decode(UUID.self, forKey: .id) {
            id = uuid
        } else {
            // Legacy format: id was a string (path), generate a new UUID
            id = UUID()
        }
        
        path = try container.decode(String.self, forKey: .path)
        lastModified = try container.decodeIfPresent(Date.self, forKey: .lastModified) ?? Date()
    }
    
    // Custom encoder
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(path, forKey: .path)
        try container.encode(lastModified, forKey: .lastModified)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case path
        case lastModified
    }
    
    /// Check if the file exists on disk
    var exists: Bool {
        FileManager.default.fileExists(atPath: path)
    }
    
    /// Get the file name
    var fileName: String {
        URL(fileURLWithPath: path).lastPathComponent
    }
    
    /// Get the file size in bytes
    var fileSize: Int64? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attributes[.size] as? Int64 else {
            return nil
        }
        return size
    }

    /// Get the file modification date from the filesystem
    var fileModificationDate: Date? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let date = attributes[.modificationDate] as? Date else {
            return nil
        }
        return date
    }
    
    /// Get image dimensions
    var dimensions: CGSize? {
        guard let imageSource = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat else {
            return nil
        }
        return CGSize(width: width, height: height)
    }
    
    /// Load the image
    func loadImage() -> NSImage? {
        NSImage(contentsOfFile: path)
    }
}
