import Foundation
import AppKit
import ImageIO

/// Service for loading images asynchronously
actor ImageLoader {
    private var cache: [String: NSImage] = [:]
    private var cacheSizes: [String: Int] = [:]
    private var loadingTasks: [String: Task<NSImage?, Never>] = [:]
    private let maxCacheSize: Int = 500 * 1024 * 1024 // 500 MB
    private var currentCacheSize: Int = 0

    // Maximum pixel dimension kept in memory. Images larger than this are downsampled
    // before caching so a 6000×4000 source doesn't consume ~96 MB per entry.
    private let maxCachedDimension: Int = 3840 // 4 K

    /// Load an image from a file path
    func loadImage(from path: String) async -> NSImage? {
        if let cached = cache[path] {
            return cached
        }

        // Cancel any existing loading task for this path
        loadingTasks[path]?.cancel()

        let maxDim = maxCachedDimension
        let task = Task<NSImage?, Never> {
            guard let image = downsample(path: path, maxDimension: maxDim) else {
                return nil
            }
            cacheImage(image, for: path)
            return image
        }

        loadingTasks[path] = task
        let result = await task.value
        loadingTasks.removeValue(forKey: path)

        return result
    }

    /// Cancel loading for a specific path
    func cancelLoading(for path: String) {
        loadingTasks[path]?.cancel()
        loadingTasks.removeValue(forKey: path)
    }

    /// Clear the cache
    func clearCache() {
        cache.removeAll()
        cacheSizes.removeAll()
        currentCacheSize = 0
    }

    /// Get cache statistics
    func getCacheStats() -> (count: Int, sizeBytes: Int) {
        (count: cache.count, sizeBytes: currentCacheSize)
    }

    // MARK: - Private

    /// Load and optionally downsample an image to `maxDimension` px on its longest side.
    /// Uses CGImageSource so the downsampling happens in one pass without loading the
    /// full uncompressed bitmap first.
    private func downsample(path: String, maxDimension: Int) -> NSImage? {
        let url = URL(fileURLWithPath: path) as CFURL
        guard let source = CGImageSourceCreateWithURL(url, nil) else { return nil }

        // Read pixel dimensions from metadata to decide whether downsampling is needed.
        var needsDownsample = false
        if let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
           let w = props[kCGImagePropertyPixelWidth] as? Int,
           let h = props[kCGImagePropertyPixelHeight] as? Int {
            needsDownsample = max(w, h) > maxDimension
        }

        if needsDownsample {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: maxDimension,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: false
            ]
            if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
                return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            }
        }

        // Image fits within the limit — load normally.
        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    /// Store an image in the cache, evicting old entries if over the size limit.
    /// Size is estimated from pixel dimensions without any TIFF round-trip.
    private func cacheImage(_ image: NSImage, for path: String) {
        let pixelWidth: Int
        let pixelHeight: Int
        if let rep = image.representations.first as? NSBitmapImageRep {
            pixelWidth = rep.pixelsWide
            pixelHeight = rep.pixelsHigh
        } else {
            // Fallback: NSImage.size is in points but good enough for the estimate.
            pixelWidth = Int(image.size.width)
            pixelHeight = Int(image.size.height)
        }
        let imageSize = pixelWidth * pixelHeight * 4

        while currentCacheSize + imageSize > maxCacheSize, let firstKey = cache.keys.first {
            let evicted = cacheSizes.removeValue(forKey: firstKey) ?? 0
            cache.removeValue(forKey: firstKey)
            currentCacheSize -= evicted
        }

        cache[path] = image
        cacheSizes[path] = imageSize
        currentCacheSize += imageSize
    }
}
