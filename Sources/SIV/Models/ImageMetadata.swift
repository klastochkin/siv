import Foundation
import ImageIO

/// Cached filesystem and image metadata for an ImageFile.
/// Loaded once off the main thread; results stored in AlbumViewModel.metadata.
struct ImageMetadata {
    let exists: Bool
    let fileSize: Int64?
    let modificationDate: Date?
    let dimensions: CGSize?

    /// Load all metadata for an image file in a single pass.
    /// Safe to call on any thread.
    static func load(for image: ImageFile) -> ImageMetadata {
        // One attributesOfItem call yields both size and modification date.
        let attrs = try? FileManager.default.attributesOfItem(atPath: image.path)
        guard let attrs else {
            return ImageMetadata(exists: false, fileSize: nil, modificationDate: nil, dimensions: nil)
        }

        let fileSize = attrs[.size] as? Int64
        let modDate = attrs[.modificationDate] as? Date

        var dimensions: CGSize?
        let url = URL(fileURLWithPath: image.path) as CFURL
        if let source = CGImageSourceCreateWithURL(url, nil),
           let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
           let w = props[kCGImagePropertyPixelWidth] as? CGFloat,
           let h = props[kCGImagePropertyPixelHeight] as? CGFloat {
            dimensions = CGSize(width: w, height: h)
        }

        return ImageMetadata(exists: true, fileSize: fileSize, modificationDate: modDate, dimensions: dimensions)
    }
}
