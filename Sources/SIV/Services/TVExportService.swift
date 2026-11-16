import Foundation
import CryptoKit
import ImageIO
import CoreGraphics
import CoreImage
import UniformTypeIdentifiers

/// How large the published full-screen images are.
enum TVExportSize: String, CaseIterable, Identifiable {
    /// Fit inside 1920×1080 and sharpen: Samsung web apps render at 1080p on every model,
    /// so pre-sizing on the Mac avoids a second, softer resize in the TV browser.
    case fullHD = "fullhd"
    /// Keep the source resolution (still re-encoded as sRGB JPEG without metadata).
    case original

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fullHD: return "Full HD (1920×1080, sharpened)"
        case .original: return "Original Size"
        }
    }
}

struct TVPixelBox: Equatable {
    var width: Int
    var height: Int
}

struct TVExportOptions: Equatable {
    static let fullHDBox = TVPixelBox(width: 1920, height: 1080)

    var thumbMaxPixelSize: Int = 480
    /// Box the full image is scaled to fit inside (never upscaled); nil keeps the source resolution.
    var fullFitBox: TVPixelBox? = TVExportOptions.fullHDBox
    var sharpen: Bool = true
    var jpegQuality: Double = 0.92

    static func preset(_ size: TVExportSize) -> TVExportOptions {
        switch size {
        case .fullHD: return TVExportOptions()
        case .original: return TVExportOptions(fullFitBox: nil, sharpen: false)
        }
    }

    /// Part of every photo id, so changing output settings regenerates all files.
    var profileKey: String {
        let full = fullFitBox.map { "\($0.width)x\($0.height)" } ?? "orig"
        return "v2-t\(thumbMaxPixelSize)-f\(full)-s\(sharpen ? 1 : 0)-q\(Int((jpegQuality * 100).rounded()))"
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
              CGImageSourceGetCount(source) > 0,
              let sourceSize = orientedPixelSize(of: source) else {
            return .failed("Unreadable image")
        }
        let target = options.fullFitBox.map { fit(sourceSize, in: $0) } ?? sourceSize
        // Decode at up to 2× the target so the final high-quality resize has detail to work with.
        let decodeLongEdge = min(max(sourceSize.width, sourceSize.height), 2 * max(target.width, target.height))
        let decodeOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: decodeLongEdge,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let decoded = CGImageSourceCreateThumbnailAtIndex(source, 0, decodeOptions as CFDictionary),
              let resized = render(decoded, width: target.width, height: target.height),
              let full = options.sharpen ? sharpened(resized) : resized,
              let thumb = render(resized, maxPixelSize: options.thumbMaxPixelSize),
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

    /// Pixel size after applying EXIF orientation (orientations 5–8 swap width and height).
    static func orientedPixelSize(of source: CGImageSource) -> TVPixelBox? {
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? Int,
              let height = props[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0 else {
            return nil
        }
        let orientation = props[kCGImagePropertyOrientation] as? Int ?? 1
        return (5...8).contains(orientation)
            ? TVPixelBox(width: height, height: width)
            : TVPixelBox(width: width, height: height)
    }

    /// Largest size with the same aspect ratio that fits inside `box` (never upscales).
    static func fit(_ size: TVPixelBox, in box: TVPixelBox) -> TVPixelBox {
        let scale = min(Double(box.width) / Double(size.width), Double(box.height) / Double(size.height), 1)
        return TVPixelBox(
            width: max(1, Int((Double(size.width) * scale).rounded())),
            height: max(1, Int((Double(size.height) * scale).rounded()))
        )
    }

    /// Draws `image` into an 8-bit sRGB bitmap no larger than `maxPixelSize` on the long edge (never upscales).
    static func render(_ image: CGImage, maxPixelSize: Int) -> CGImage? {
        let size = fit(
            TVPixelBox(width: image.width, height: image.height),
            in: TVPixelBox(width: maxPixelSize, height: maxPixelSize)
        )
        return render(image, width: size.width, height: size.height)
    }

    private static let sharpenContext: CIContext = {
        let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
        return CIContext(options: [.workingColorSpace: srgb, .outputColorSpace: srgb, .cacheIntermediates: false])
    }()

    /// Light unsharp mask tuned for the TV's 2× upscale of 1080p app content.
    static func sharpened(_ image: CGImage, radius: Double = 0.8, intensity: Double = 0.35) -> CGImage? {
        let input = CIImage(cgImage: image)
        guard let filter = CIFilter(name: "CIUnsharpMask"),
              let srgb = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        filter.setValue(input.clampedToExtent(), forKey: kCIInputImageKey)
        filter.setValue(radius, forKey: kCIInputRadiusKey)
        filter.setValue(intensity, forKey: kCIInputIntensityKey)
        guard let output = filter.outputImage?.cropped(to: input.extent) else { return nil }
        return sharpenContext.createCGImage(output, from: input.extent, format: .RGBA8, colorSpace: srgb)
    }

    /// Draws `image` into an 8-bit sRGB bitmap of exactly `width`×`height`.
    static func render(_ image: CGImage, width: Int, height: Int) -> CGImage? {
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
