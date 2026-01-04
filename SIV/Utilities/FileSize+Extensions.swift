import Foundation

extension Int64 {
    /// Formats byte count as human-readable file size
    var formattedFileSize: String {
        return ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}

extension URL {
    /// Gets the file size in bytes
    var fileSize: Int64? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path) else {
            return nil
        }
        return attributes[.size] as? Int64
    }
    
    /// Checks if the URL is a supported image format
    var isSupportedImageFormat: Bool {
        let ext = pathExtension.lowercased()
        return ImageFormat.supportedExtensions.contains(ext)
    }
}

