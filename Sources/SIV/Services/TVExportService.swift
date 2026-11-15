import Foundation
import CryptoKit
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers

struct TVExportOptions: Equatable {
    var thumbMaxPixelSize: Int = 480
    /// Tizen web apps typically render at 1920×1080 even on 4K panels; 2560 leaves headroom.
    var fullMaxPixelSize: Int = 2560
    var jpegQuality: Double = 0.85

    /// Part of every photo id, so changing output settings regenerates all files.
    var profileKey: String {
        "v1-t\(thumbMaxPixelSize)-f\(fullMaxPixelSize)-q\(Int(jpegQuality * 100))"
    }
}

struct TVExportFailure: Equatable {
    let path: String
    let reason: String
}

struct TVExportReport: Equatable {
    var exported = 0
    var reused = 0
    var removed = 0
    var missing: [String] = []
    var failed: [TVExportFailure] = []

    var published: Int { exported + reused }

    var summary: String {
        var parts = ["\(published) photo(s) published (\(exported) new, \(reused) unchanged)"]
        if removed > 0 { parts.append("\(removed) stale file(s) removed") }
        if !missing.isEmpty { parts.append("\(missing.count) missing") }
        if !failed.isEmpty { parts.append("\(failed.count) failed") }
        return parts.joined(separator: ", ")
    }
}

enum TVExportError: LocalizedError {
    case cannotCreateDirectory(String)
    case cannotWriteIndex(String)

    var errorDescription: String? {
        switch self {
        case .cannotCreateDirectory(let path): return "Cannot create folder \(path)"
        case .cannotWriteIndex(let reason): return "Cannot write index.json: \(reason)"
        }
    }
}

/// Builds the static TV library tree (`index.json`, `thumbs/`, `full/`) from album images.
///
/// Published JPEGs are re-encoded in sRGB with orientation applied and no metadata,
/// so camera EXIF (including GPS) never reaches the LAN server.
enum TVExportService {
    static let thumbsDirectory = "thumbs"
    static let fullDirectory = "full"
    private static let maxConcurrentDecodes = 4

    /// Stable id derived from source path, size, mtime and output profile.
    /// Editing or replacing a source file yields a new id, so TV caches never serve stale pixels.
    static func photoID(path: String, size: Int64, modificationDate: Date, options: TVExportOptions) -> String {
        let key = "\(path)|\(size)|\(Int64(modificationDate.timeIntervalSince1970 * 1000))|\(options.profileKey)"
        let digest = SHA256.hash(data: Data(key.utf8))
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    static func isPublishedFileName(_ name: String) -> Bool {
        guard name.hasSuffix(".jpg") else { return false }
        let stem = name.dropLast(4)
        return stem.count == 16 && stem.allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }

    @discardableResult
    static func export(
        images: [ImageFile],
        albumName: String,
        to root: URL,
        options: TVExportOptions = TVExportOptions(),
        now: Date = Date(),
        progress: ((_ done: Int, _ total: Int) -> Void)? = nil
    ) throws -> TVExportReport {
        let fm = FileManager.default
        let thumbsURL = root.appendingPathComponent(thumbsDirectory, isDirectory: true)
        let fullURL = root.appendingPathComponent(fullDirectory, isDirectory: true)
        for dir in [root, thumbsURL, fullURL] {
            do {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            } catch {
                throw TVExportError.cannotCreateDirectory(dir.path)
            }
        }

        let total = images.count
        var outcomes = [Outcome?](repeating: nil, count: total)
        let lock = NSLock()
        var nextIndex = 0
        var done = 0

        let workers = max(1, min(maxConcurrentDecodes, total))
        DispatchQueue.concurrentPerform(iterations: workers) { _ in
            while true {
                lock.lock()
                let index = nextIndex
                nextIndex += 1
                lock.unlock()
                guard index < total else { return }

                let outcome = autoreleasepool {
                    process(images[index], thumbsURL: thumbsURL, fullURL: fullURL, options: options)
                }

                lock.lock()
                outcomes[index] = outcome
                done += 1
                let current = done
                lock.unlock()
                progress?(current, total)
            }
        }

        var report = TVExportReport()
        var photos: [TVPhoto] = []
        for (index, outcome) in outcomes.enumerated() {
            switch outcome {
            case .exported(let photo):
                report.exported += 1
                photos.append(photo)
            case .reused(let photo):
                report.reused += 1
                photos.append(photo)
            case .missing:
                report.missing.append(images[index].path)
            case .failed(let reason):
                report.failed.append(TVExportFailure(path: images[index].path, reason: reason))
            case nil:
                report.failed.append(TVExportFailure(path: images[index].path, reason: "Not processed"))
            }
        }

        let index = TVLibraryIndex(generatedAt: now, albumName: albumName, photos: photos)
        do {
            let data = try TVLibraryIndex.makeEncoder().encode(index)
            try data.write(to: root.appendingPathComponent(TVLibraryIndex.fileName), options: .atomic)
        } catch {
            throw TVExportError.cannotWriteIndex(error.localizedDescription)
        }

        // Stale files are removed only after the new index is in place, so a TV
        // reading mid-export never sees an index pointing at deleted files.
        let liveNames = Set(photos.map { "\($0.id).jpg" })
        for dir in [thumbsURL, fullURL] {
            let names = (try? fm.contentsOfDirectory(atPath: dir.path)) ?? []
            for name in names where isPublishedFileName(name) && !liveNames.contains(name) {
                if (try? fm.removeItem(at: dir.appendingPathComponent(name))) != nil {
                    report.removed += 1
                }
            }
        }

        return report
    }

    // MARK: - Per-image work

    private enum Outcome {
        case exported(TVPhoto)
        case reused(TVPhoto)
        case missing
        case failed(String)
    }

    private static func process(_ image: ImageFile, thumbsURL: URL, fullURL: URL, options: TVExportOptions) -> Outcome {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: image.path),
              (attrs[.type] as? FileAttributeType) == .typeRegular else {
            return .missing
        }
        let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
        let mtime = attrs[.modificationDate] as? Date ?? .distantPast
        let id = photoID(path: image.path, size: size, modificationDate: mtime, options: options)
        let name = "\(id).jpg"
        let thumbFile = thumbsURL.appendingPathComponent(name)
        let fullFile = fullURL.appendingPathComponent(name)
        let takenAt = ExifService.readExifData(from: image.path)?.dateTimeOriginal

        func photo(width: Int, height: Int) -> TVPhoto {
            TVPhoto(
                id: id,
                title: image.fileName,
                takenAt: takenAt,
                thumb: "\(thumbsDirectory)/\(name)",
                full: "\(fullDirectory)/\(name)",
                width: width,
                height: height
            )
        }

        let fm = FileManager.default
        if fm.fileExists(atPath: thumbFile.path), fm.fileExists(atPath: fullFile.path),
           let dims = pixelSize(of: fullFile) {
            return .reused(photo(width: dims.width, height: dims.height))
        }

        guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: image.path) as CFURL, nil),
              CGImageSourceGetCount(source) > 0 else {
            return .failed("Unreadable image")
        }
        let decodeOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: options.fullMaxPixelSize,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let decoded = CGImageSourceCreateThumbnailAtIndex(source, 0, decodeOptions as CFDictionary),
              let full = render(decoded, maxPixelSize: options.fullMaxPixelSize),
              let thumb = render(full, maxPixelSize: options.thumbMaxPixelSize),
              let fullData = jpegData(full, quality: options.jpegQuality),
              let thumbData = jpegData(thumb, quality: options.jpegQuality) else {
            return .failed("Cannot decode or encode image")
        }

        do {
            try thumbData.write(to: thumbFile, options: .atomic)
            try fullData.write(to: fullFile, options: .atomic)
        } catch {
            return .failed(error.localizedDescription)
        }
        return .exported(photo(width: full.width, height: full.height))
    }

    // MARK: - Image helpers

    static func pixelSize(of url: URL) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? Int,
              let height = props[kCGImagePropertyPixelHeight] as? Int else {
            return nil
        }
        return (width, height)
    }

    /// Draws `image` into an 8-bit sRGB bitmap no larger than `maxPixelSize` on the long edge (never upscales).
    static func render(_ image: CGImage, maxPixelSize: Int) -> CGImage? {
        let longEdge = max(image.width, image.height)
        let scale = longEdge > maxPixelSize ? Double(maxPixelSize) / Double(longEdge) : 1
        let width = max(1, Int((Double(image.width) * scale).rounded()))
        let height = max(1, Int((Double(image.height) * scale).rounded()))
        guard let srgb = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: srgb, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              ) else {
            return nil
        }
        context.interpolationQuality = .high
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    static func jpegData(_ image: CGImage, quality: Double) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }
}
