import Foundation
import AppKit
import ImageIO

/// Tiered async image cache.
///
/// Tier 2 — full quality (fullQualityDimension px max): kept for the current image ±
///   the navigation window. Budget = totalCacheBytes - previewCacheBytes.
/// Tier 1 — preview quality (previewDimension px max): large LRU window for fast
///   first-paint while the full quality loads in background.
/// Tier 0 — 200 px thumbnails: live in AlbumViewModel.thumbnails, not here.
actor ImageLoader {

    // ─── Tuneable constants ───────────────────────────────────────────────────
    /// Total RAM budget for both tiers combined.
    static let totalCacheBytes: Int = 500 * 1024 * 1024     // 500 MB

    /// RAM reserved for Tier 1 (preview). Tier 2 gets the remainder.
    /// At 500 MB total and 2.4 MB / 960-px image this keeps ~130 preview images.
    /// At 500 MB total and 37.5 MB / 3840-px image Tier 2 gets ~5 full images.
    static let previewCacheBytes: Int = 300 * 1024 * 1024   // 300 MB → Tier 1
    // Tier 2 budget = 500 - 300 = 200 MB ≈ 5 × 37.5 MB

    static let fullQualityDimension: Int = 3840  // px — Tier 2
    static let previewDimension: Int     = 960   // px — Tier 1

    // ─── Tier 2 state ─────────────────────────────────────────────────────────
    private var fullCache: [String: NSImage] = [:]
    private var fullOrder: [String] = []            // head = LRU, tail = MRU
    private var fullSizes: [String: Int] = [:]
    private var fullUsed: Int = 0

    // ─── Tier 1 state ─────────────────────────────────────────────────────────
    private var previewCache: [String: NSImage] = [:]
    private var previewOrder: [String] = []
    private var previewSizes: [String: Int] = [:]
    private var previewUsed: Int = 0

    // ─── In-flight tasks ──────────────────────────────────────────────────────
    private var fullTasks:    [String: Task<NSImage?, Never>] = [:]
    private var previewTasks: [String: Task<NSImage?, Never>] = [:]

    // MARK: - Public API

    /// Returns true if the full-quality image is already in Tier 2 (no I/O needed).
    func isFullyCached(path: String) -> Bool {
        fullCache[path] != nil
    }

    /// Load full-quality image (Tier 2). Cancels any in-flight load for this path.
    func loadImage(from path: String) async -> NSImage? {
        if let hit = lruGet(path, cache: &fullCache, order: &fullOrder) {
            return hit
        }
        fullTasks[path]?.cancel()
        let task = makeDecodeTask(path: path, dimension: Self.fullQualityDimension)
        fullTasks[path] = task
        let result = await task.value
        fullTasks.removeValue(forKey: path)
        if let image = result {
            lruStore(path, image: image,
                     cache: &fullCache, order: &fullOrder,
                     sizes: &fullSizes, used: &fullUsed,
                     maxBytes: Self.totalCacheBytes - Self.previewCacheBytes)
        }
        return result
    }

    /// Load preview-quality image (Tier 1). Reuses an in-flight task if present.
    func loadPreview(from path: String) async -> NSImage? {
        if let hit = lruGet(path, cache: &previewCache, order: &previewOrder) {
            return hit
        }
        // Reuse an existing task rather than cancelling — preview is cheap and
        // multiple callers (prefetch + display) may request the same path.
        if let existing = previewTasks[path] {
            return await existing.value
        }
        let task = makeDecodeTask(path: path, dimension: Self.previewDimension)
        previewTasks[path] = task
        let result = await task.value
        previewTasks.removeValue(forKey: path)
        if let image = result {
            lruStore(path, image: image,
                     cache: &previewCache, order: &previewOrder,
                     sizes: &previewSizes, used: &previewUsed,
                     maxBytes: Self.previewCacheBytes)
        }
        return result
    }

    /// Background prefetch of full-quality image. No-op if already cached or loading.
    func prefetch(path: String) async {
        guard fullCache[path] == nil, fullTasks[path] == nil else { return }
        _ = await loadImage(from: path)
    }

    /// Cancel all in-flight loads for a path.
    func cancelLoading(for path: String) {
        fullTasks[path]?.cancel()
        fullTasks.removeValue(forKey: path)
        previewTasks[path]?.cancel()
        previewTasks.removeValue(forKey: path)
    }

    func clearCache() {
        fullCache.removeAll(); fullOrder.removeAll()
        fullSizes.removeAll(); fullUsed = 0
        previewCache.removeAll(); previewOrder.removeAll()
        previewSizes.removeAll(); previewUsed = 0
    }

    func getCacheStats() -> (fullCount: Int, fullMB: Int, previewCount: Int, previewMB: Int) {
        (fullCache.count, fullUsed / (1024 * 1024),
         previewCache.count, previewUsed / (1024 * 1024))
    }

    // MARK: - Private helpers

    /// Create a non-isolated Task that decodes the image off the actor's executor.
    private func makeDecodeTask(path: String, dimension: Int) -> Task<NSImage?, Never> {
        Task.detached(priority: .userInitiated) {
            ImageLoader.decode(path: path, maxDimension: dimension)
        }
    }

    /// Decode and optionally downsample an image. Safe to call on any thread.
    static nonisolated func decode(path: String, maxDimension: Int) -> NSImage? {
        let url = URL(fileURLWithPath: path) as CFURL
        guard let source = CGImageSourceCreateWithURL(url, nil) else { return nil }

        var needsDownsample = false
        if let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
           let w = props[kCGImagePropertyPixelWidth] as? Int,
           let h = props[kCGImagePropertyPixelHeight] as? Int {
            needsDownsample = max(w, h) > maxDimension
        }

        if needsDownsample {
            let opts: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: maxDimension,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: false
            ]
            if let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, opts as CFDictionary) {
                return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
            }
        }

        guard let cg = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
    }

    // MARK: - LRU helpers

    private func lruGet(_ key: String,
                        cache: inout [String: NSImage],
                        order: inout [String]) -> NSImage? {
        guard let image = cache[key] else { return nil }
        order.removeAll { $0 == key }
        order.append(key)
        return image
    }

    private func lruStore(_ key: String, image: NSImage,
                          cache: inout [String: NSImage],
                          order: inout [String],
                          sizes: inout [String: Int],
                          used: inout Int,
                          maxBytes: Int) {
        let size = pixelBytes(image)

        // Remove existing entry for this key first
        if let old = sizes[key] {
            used -= old
            cache.removeValue(forKey: key)
            order.removeAll { $0 == key }
            sizes.removeValue(forKey: key)
        }

        // Evict LRU entries until there is room
        while used + size > maxBytes, let oldest = order.first {
            order.removeFirst()
            let evicted = sizes.removeValue(forKey: oldest) ?? 0
            cache.removeValue(forKey: oldest)
            used -= evicted
        }

        cache[key] = image
        order.append(key)
        sizes[key] = size
        used += size
    }

    private func pixelBytes(_ image: NSImage) -> Int {
        if let rep = image.representations.first as? NSBitmapImageRep {
            return rep.pixelsWide * rep.pixelsHigh * 4
        }
        return Int(image.size.width * image.size.height * 4)
    }
}
