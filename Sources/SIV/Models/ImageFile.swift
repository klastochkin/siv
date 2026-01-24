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
