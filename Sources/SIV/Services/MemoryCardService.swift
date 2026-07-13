import Foundation

/// A detected removable volume that may be a camera memory card.
struct MemoryCard: Identifiable, Hashable, Sendable {
    let id = UUID()
    let name: String
    let url: URL
    /// True when the volume contains a standard camera `DCIM` directory.
    let hasDCIM: Bool
}

/// Detects memory cards and enumerates image files stored on them.
enum MemoryCardService {
    /// File extensions we treat as importable images (matches the album's supported set).
    static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "tiff", "tif", "gif", "bmp", "webp"
    ]

    /// Find connected memory cards.
    ///
    /// A card is a volume whose media is removable or ejectable (this covers USB card
    /// readers as well as built-in SD slots, which macOS reports as an *internal* bus
    /// with *removable* media), or any volume that contains a camera `DCIM` folder.
    /// System/boot volumes are excluded.
    /// Cards with a `DCIM` folder are listed first.
    static func detectCards() -> [MemoryCard] {
        let keys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeIsRemovableKey,
            .volumeIsEjectableKey,
            .volumeIsRootFileSystemKey
        ]
        guard let volumes = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: [.skipHiddenVolumes]
        ) else { return [] }

        var cards: [MemoryCard] = []
        for url in volumes {
            // Never treat the boot volume or macOS system volumes as a card.
            if url.path == "/" || url.path.hasPrefix("/System/Volumes") { continue }
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { continue }
            if values.volumeIsRootFileSystem ?? false { continue }

            let removable = (values.volumeIsRemovable ?? false) || (values.volumeIsEjectable ?? false)
            let hasDCIM = FileManager.default.fileExists(
                atPath: url.appendingPathComponent("DCIM").path
            )
            guard removable || hasDCIM else { continue }

            let name = values.volumeName ?? url.lastPathComponent
            log("💾 MemoryCardService: candidate '\(name)' at \(url.path) (removable=\(removable), DCIM=\(hasDCIM))")
            cards.append(MemoryCard(name: name, url: url, hasDCIM: hasDCIM))
        }

        return cards.sorted { lhs, rhs in
            if lhs.hasDCIM != rhs.hasDCIM { return lhs.hasDCIM }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    /// Enumerate every image file on the card, sorted by filename in natural order.
    static func imageFiles(on cardURL: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: cardURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var files: [URL] = []
        for case let fileURL as URL in enumerator {
            if imageExtensions.contains(fileURL.pathExtension.lowercased()) {
                files.append(fileURL)
            }
        }
        files.sort {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
        return files
    }
}
