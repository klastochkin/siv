import AppKit
import CoreGraphics
import ImageIO

/// Service responsible for loading and decoding images
class ImageLoader {
    
    /// Errors that can occur during image loading
    enum ImageLoadError: Error {
        case fileNotFound
        case unsupportedFormat
        case corruptedFile
        case permissionDenied
        case unknownError(String)
    }
    
    /// Asynchronously loads an image from disk
    func loadImage(from url: URL) async throws -> NSImage {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    // Check file exists
                    guard FileManager.default.fileExists(atPath: url.path) else {
                        throw ImageLoadError.fileNotFound
                    }
                    
                    // Check file is readable
                    guard FileManager.default.isReadableFile(atPath: url.path) else {
                        throw ImageLoadError.permissionDenied
                    }
                    
                    // Load image
                    guard let image = NSImage(contentsOf: url) else {
                        throw ImageLoadError.corruptedFile
                    }
                    
                    continuation.resume(returning: image)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Gets metadata for an image file without loading the full image
    func getMetadata(for url: URL) throws -> ImageMetadata {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw ImageLoadError.corruptedFile
        }
        
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            throw ImageLoadError.corruptedFile
        }
        
        // Extract dimensions
        let width = properties[kCGImagePropertyPixelWidth as String] as? CGFloat ?? 0
        let height = properties[kCGImagePropertyPixelHeight as String] as? CGFloat ?? 0
        let dimensions = CGSize(width: width, height: height)
        
        // Extract DPI
        let dpiX = properties[kCGImagePropertyDPIWidth as String] as? CGFloat
        let dpiY = properties[kCGImagePropertyDPIHeight as String] as? CGFloat
        let dpi = dpiX ?? dpiY
        
        // Get file size
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        
        // Determine format
        let format = ImageFormat(rawValue: url.pathExtension.uppercased()) ?? .jpeg
        
        // Get color space
        let colorSpace = properties[kCGImagePropertyColorModel as String] as? String ?? "Unknown"
        
        return ImageMetadata(
            dimensions: dimensions,
            fileSize: fileSize,
            colorSpace: colorSpace,
            dpi: dpi,
            format: format
        )
    }
}

/// Metadata extracted from an image file
struct ImageMetadata {
    let dimensions: CGSize
    let fileSize: Int64
    let colorSpace: String
    let dpi: CGFloat?
    let format: ImageFormat
}

