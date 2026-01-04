import AppKit

/// LRU cache for loaded images to improve performance
class ImageCache {
    
    private struct CacheEntry {
        let image: NSImage
        let timestamp: Date
        let size: Int64
    }
    
    private var cache: [URL: CacheEntry] = [:]
    private var accessOrder: [URL] = []
    
    /// Maximum memory usage in bytes (500MB)
    private let maxMemoryBytes: Int64 = 500 * 1024 * 1024
    
    /// Current memory usage in bytes
    private var currentMemoryBytes: Int64 = 0
    
    private let lock = NSLock()
    
    /// Retrieves an image from cache if available
    func get(_ url: URL) -> NSImage? {
        lock.lock()
        defer { lock.unlock() }
        
        guard let entry = cache[url] else {
            return nil
        }
        
        // Update access order (LRU)
        if let index = accessOrder.firstIndex(of: url) {
            accessOrder.remove(at: index)
        }
        accessOrder.append(url)
        
        return entry.image
    }
    
    /// Stores an image in cache
    func set(_ image: NSImage, for url: URL, size: Int64) {
        lock.lock()
        defer { lock.unlock() }
        
        // Remove existing entry if present
        if let existingEntry = cache[url] {
            currentMemoryBytes -= existingEntry.size
        }
        
        // Add new entry
        let entry = CacheEntry(image: image, timestamp: Date(), size: size)
        cache[url] = entry
        currentMemoryBytes += size
        
        // Update access order
        if let index = accessOrder.firstIndex(of: url) {
            accessOrder.remove(at: index)
        }
        accessOrder.append(url)
        
        // Evict oldest entries if over memory limit
        while currentMemoryBytes > maxMemoryBytes && !accessOrder.isEmpty {
            let oldestURL = accessOrder.removeFirst()
            if let entry = cache.removeValue(forKey: oldestURL) {
                currentMemoryBytes -= entry.size
            }
        }
    }
    
    /// Removes an image from cache
    func remove(_ url: URL) {
        lock.lock()
        defer { lock.unlock() }
        
        if let entry = cache.removeValue(forKey: url) {
            currentMemoryBytes -= entry.size
        }
        
        if let index = accessOrder.firstIndex(of: url) {
            accessOrder.remove(at: index)
        }
    }
    
    /// Clears the entire cache
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        
        cache.removeAll()
        accessOrder.removeAll()
        currentMemoryBytes = 0
    }
    
    /// Returns current cache statistics
    func stats() -> (count: Int, memoryMB: Double) {
        lock.lock()
        defer { lock.unlock() }
        
        let memoryMB = Double(currentMemoryBytes) / (1024 * 1024)
        return (cache.count, memoryMB)
    }
}

