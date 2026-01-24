import Foundation
import AppKit

/// Service for loading images asynchronously
actor ImageLoader {
    private var cache: [String: NSImage] = [:]
    private var loadingTasks: [String: Task<NSImage?, Never>] = [:]
    private let maxCacheSize: Int = 500 * 1024 * 1024 // 500MB
    private var currentCacheSize: Int = 0
    
    /// Load an image from a file path
    func loadImage(from path: String) async -> NSImage? {
        // Check cache first
        if let cached = cache[path] {
            return cached
        }
        
        // Cancel any existing loading task for this path
        loadingTasks[path]?.cancel()
        
        // Create new loading task
        let task = Task<NSImage?, Never> {
            guard let image = NSImage(contentsOfFile: path) else {
                return nil
            }
            
            // Cache the image
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
    
    /// Cache an image
    private func cacheImage(_ image: NSImage, for path: String) {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return
        }
        
        let imageSize = bitmap.pixelsWide * bitmap.pixelsHigh * 4 // Approximate size in bytes
        
        // Evict old images if cache is too large
        while currentCacheSize + imageSize > maxCacheSize && !cache.isEmpty {
            if let firstKey = cache.keys.first {
                cache.removeValue(forKey: firstKey)
                currentCacheSize -= imageSize // Approximate
            }
        }
        
        cache[path] = image
        currentCacheSize += imageSize
    }
    
    /// Clear the cache
    func clearCache() {
        cache.removeAll()
        currentCacheSize = 0
    }
    
    /// Get cache statistics
    func getCacheStats() -> (count: Int, sizeBytes: Int) {
        (count: cache.count, sizeBytes: currentCacheSize)
    }
}
