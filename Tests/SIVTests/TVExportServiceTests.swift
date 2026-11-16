import XCTest
import ImageIO
import UniformTypeIdentifiers
@testable import SIV

final class TVExportServiceTests: XCTestCase {
    private var sourceDir: URL!
    private var libraryDir: URL!
    private let options = TVExportOptions(
        thumbMaxPixelSize: 64, fullFitBox: TVPixelBox(width: 256, height: 256), sharpen: false, jpegQuality: 0.8
    )

    override func setUp() {
        super.setUp()
        sourceDir = TVTestSupport.makeTempDirectory("siv-tv-src")
        libraryDir = TVTestSupport.makeTempDirectory("siv-tv-lib").appendingPathComponent("library")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: sourceDir)
        try? FileManager.default.removeItem(at: libraryDir.deletingLastPathComponent())
        super.tearDown()
    }

    private func source(_ name: String, width: Int = 400, height: Int = 300, type: UTType = .jpeg,
                        alpha: Bool = false, orientation: Int? = nil, date: String? = nil, gps: Bool = false) -> ImageFile {
        let url = TVTestSupport.writeImage(
            to: sourceDir.appendingPathComponent(name), width: width, height: height, type: type,
            alpha: alpha, orientation: orientation, dateTimeOriginal: date, withGPS: gps
        )
        return ImageFile(path: url.path)
    }

    @discardableResult
    private func export(_ images: [ImageFile], options: TVExportOptions? = nil) throws -> TVExportReport {
        try TVExportService.export(images: images, albumName: "Test", to: libraryDir, options: options ?? self.options)
    }

    private func publishedFiles(_ dir: String) -> Set<String> {
        Set((try? FileManager.default.contentsOfDirectory(atPath: libraryDir.appendingPathComponent(dir).path)) ?? [])
    }

    // MARK: - Layout and index

    func testExportCreatesTreeAndIndexInAlbumOrder() throws {
        let images = [source("b.jpg"), source("a.png", type: .png), source("c.jpg")]
        let report = try export(images)

        XCTAssertEqual(report.exported, 3)
        XCTAssertEqual(report.reused, 0)
        XCTAssertTrue(report.failed.isEmpty)
        XCTAssertTrue(report.missing.isEmpty)

        let index = try TVTestSupport.readIndex(libraryDir)
        XCTAssertEqual(index.version, TVLibraryIndex.currentVersion)
        XCTAssertEqual(index.albumName, "Test")
        XCTAssertEqual(index.photos.map(\.title), ["b.jpg", "a.png", "c.jpg"])
        XCTAssertEqual(Set(index.photos.map(\.id)).count, 3)

        for photo in index.photos {
            XCTAssertEqual(photo.thumb, "thumbs/\(photo.id).jpg")
            XCTAssertEqual(photo.full, "full/\(photo.id).jpg")
            XCTAssertTrue(TVExportService.isPublishedFileName("\(photo.id).jpg"))
            XCTAssertTrue(FileManager.default.fileExists(atPath: libraryDir.appendingPathComponent(photo.thumb).path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: libraryDir.appendingPathComponent(photo.full).path))
        }
    }

    func testIndexJSONUsesRelativePathsAndISODates() throws {
        try export([source("a.jpg", date: "2024:06:01 15:22:00")])
        let raw = try String(contentsOf: libraryDir.appendingPathComponent("index.json"), encoding: .utf8)
        let json = try JSONSerialization.jsonObject(with: Data(raw.utf8)) as! [String: Any]
        let photo = (json["photos"] as! [[String: Any]])[0]

        XCTAssertNotNil(ISO8601DateFormatter().date(from: json["generatedAt"] as! String))
        XCTAssertNotNil(ISO8601DateFormatter().date(from: photo["takenAt"] as! String))
        XCTAssertTrue((photo["thumb"] as! String).hasPrefix("thumbs/"))
        XCTAssertFalse(raw.contains(sourceDir.path), "index must not leak local source paths")
        XCTAssertFalse(raw.contains("\\/"), "slashes should not be escaped")
    }

    func testEmptyAlbumWritesEmptyIndex() throws {
        let report = try export([])
        XCTAssertEqual(report.published, 0)
        XCTAssertEqual(try TVTestSupport.readIndex(libraryDir).photos, [])
    }

    // MARK: - Image processing

    func testOutputsAreDownscaledToLimitsWithAspectRatio() throws {
        try export([source("wide.jpg", width: 1000, height: 500)])
        let photo = try TVTestSupport.readIndex(libraryDir).photos[0]
        XCTAssertEqual(photo.width, 256)
        XCTAssertEqual(photo.height, 128)

        let thumb = TVTestSupport.cgImage(at: libraryDir.appendingPathComponent(photo.thumb))!
        XCTAssertEqual(thumb.width, 64)
        XCTAssertEqual(thumb.height, 32)
        let full = TVTestSupport.cgImage(at: libraryDir.appendingPathComponent(photo.full))!
        XCTAssertEqual(full.width, 256)
    }

    func testSmallImagesAreNotUpscaled() throws {
        try export([source("tiny.jpg", width: 40, height: 30)])
        let photo = try TVTestSupport.readIndex(libraryDir).photos[0]
        XCTAssertEqual(photo.width, 40)
        XCTAssertEqual(photo.height, 30)
        let thumb = TVTestSupport.cgImage(at: libraryDir.appendingPathComponent(photo.thumb))!
        XCTAssertEqual(thumb.width, 40)
    }

    func testExifOrientationIsBakedIn() throws {
        // Orientation 6 = stored landscape, displayed rotated 90° → portrait.
        try export([source("rotated.jpg", width: 200, height: 100, orientation: 6)])
        let photo = try TVTestSupport.readIndex(libraryDir).photos[0]
        XCTAssertEqual(photo.width, 100)
        XCTAssertEqual(photo.height, 200)

        let props = TVTestSupport.properties(of: libraryDir.appendingPathComponent(photo.full))
        let orientation = props[kCGImagePropertyOrientation] as? Int ?? 1
        XCTAssertEqual(orientation, 1)
    }

    func testPublishedFilesStripGPSAndCaptureMetadata() throws {
        try export([source("gps.jpg", date: "2024:06:01 15:22:00", gps: true)])
        let photo = try TVTestSupport.readIndex(libraryDir).photos[0]
        XCTAssertNotNil(TVTestSupport.properties(of: sourceDir.appendingPathComponent("gps.jpg"))[kCGImagePropertyGPSDictionary])

        for path in [photo.thumb, photo.full] {
            let props = TVTestSupport.properties(of: libraryDir.appendingPathComponent(path))
            XCTAssertNil(props[kCGImagePropertyGPSDictionary], "\(path) leaks GPS")
            let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
            XCTAssertNil(exif[kCGImagePropertyExifDateTimeOriginal], "\(path) leaks capture time")
        }
    }

    func testOutputsAreSRGBJPEG() throws {
        try export([source("p3.png", type: .png, alpha: true)])
        let photo = try TVTestSupport.readIndex(libraryDir).photos[0]
        let url = libraryDir.appendingPathComponent(photo.full)
        let source = CGImageSourceCreateWithURL(url as CFURL, nil)!
        XCTAssertEqual(CGImageSourceGetType(source) as String?, UTType.jpeg.identifier)
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
        XCTAssertEqual(image.colorSpace?.name, CGColorSpace.sRGB)
    }

    func testHEICSourceIsConvertedToJPEG() throws {
        let probe = sourceDir.appendingPathComponent("probe.heic")
        guard CGImageDestinationCreateWithURL(probe as CFURL, UTType.heic.identifier as CFString, 1, nil) != nil else {
            throw XCTSkip("HEIC encoder unavailable")
        }
        try export([source("photo.heic", type: .heic)])
        let photo = try TVTestSupport.readIndex(libraryDir).photos[0]
        XCTAssertTrue(photo.full.hasSuffix(".jpg"))
        let source = CGImageSourceCreateWithURL(libraryDir.appendingPathComponent(photo.full) as CFURL, nil)!
        XCTAssertEqual(CGImageSourceGetType(source) as String?, UTType.jpeg.identifier)
    }

    func testTakenAtComesFromExifOrIsNil() throws {
        try export([source("dated.jpg", date: "2024:06:01 15:22:00"), source("undated.jpg")])
        let photos = try TVTestSupport.readIndex(libraryDir).photos
        let expected = ExifService.exifDateFormatter.date(from: "2024:06:01 15:22:00")
        XCTAssertEqual(photos[0].takenAt, expected)
        XCTAssertNil(photos[1].takenAt)
    }

    // MARK: - Error handling

    func testMissingAndCorruptFilesAreReportedWithoutAbortingExport() throws {
        let good = source("good.jpg")
        let missing = ImageFile(path: sourceDir.appendingPathComponent("gone.jpg").path)
        let corruptURL = sourceDir.appendingPathComponent("corrupt.jpg")
        try Data("not an image".utf8).write(to: corruptURL)
        let directory = ImageFile(path: sourceDir.path)

        let report = try export([missing, good, ImageFile(path: corruptURL.path), directory])

        XCTAssertEqual(report.exported, 1)
        XCTAssertEqual(Set(report.missing), [missing.path, sourceDir.path])
        XCTAssertEqual(report.failed.map(\.path), [corruptURL.path])
        XCTAssertEqual(try TVTestSupport.readIndex(libraryDir).photos.map(\.title), ["good.jpg"])
    }

    func testUnwritableDestinationThrows() throws {
        let blocker = libraryDir.deletingLastPathComponent().appendingPathComponent("file")
        try Data("x".utf8).write(to: blocker)
        XCTAssertThrowsError(
            try TVExportService.export(images: [source("a.jpg")], albumName: "T", to: blocker.appendingPathComponent("lib"))
        ) { error in
            guard case TVExportError.cannotCreateDirectory = error else {
                return XCTFail("unexpected error \(error)")
            }
        }
    }

    // MARK: - Incremental sync

    func testSecondExportReusesUnchangedFiles() throws {
        let images = [source("a.jpg"), source("b.jpg")]
        try export(images)
        let photo = try TVTestSupport.readIndex(libraryDir).photos[0]
        let fullURL = libraryDir.appendingPathComponent(photo.full)
        let before = try FileManager.default.attributesOfItem(atPath: fullURL.path)[.modificationDate] as! Date

        let report = try export(images)
        XCTAssertEqual(report.exported, 0)
        XCTAssertEqual(report.reused, 2)
        XCTAssertEqual(report.removed, 0)
        let after = try FileManager.default.attributesOfItem(atPath: fullURL.path)[.modificationDate] as! Date
        XCTAssertEqual(before, after)
        XCTAssertEqual(try TVTestSupport.readIndex(libraryDir).photos[0], photo)
    }

    func testModifiedSourceGetsNewIDAndOldFilesAreRemoved() throws {
        let image = source("a.jpg")
        try export([image])
        let oldID = try TVTestSupport.readIndex(libraryDir).photos[0].id

        TVTestSupport.writeImage(to: URL(fileURLWithPath: image.path), width: 500, height: 300)
        TVTestSupport.setModificationDate(Date().addingTimeInterval(60), of: URL(fileURLWithPath: image.path))
        let report = try export([image])

        let newID = try TVTestSupport.readIndex(libraryDir).photos[0].id
        XCTAssertNotEqual(oldID, newID)
        XCTAssertEqual(report.exported, 1)
        XCTAssertEqual(report.removed, 2)
        XCTAssertEqual(publishedFiles("thumbs"), ["\(newID).jpg"])
        XCTAssertEqual(publishedFiles("full"), ["\(newID).jpg"])
    }

    func testRemovedAlbumEntriesArePrunedButForeignFilesAreKept() throws {
        let a = source("a.jpg"), b = source("b.jpg")
        try export([a, b])
        let foreign = ["readme.txt", "ABCDEF0123456789.jpg", "holiday.jpg", ".DS_Store"]
        for name in foreign {
            try Data("keep".utf8).write(to: libraryDir.appendingPathComponent("thumbs").appendingPathComponent(name))
        }

        let report = try export([a])

        XCTAssertEqual(report.removed, 2)
        let index = try TVTestSupport.readIndex(libraryDir)
        XCTAssertEqual(index.photos.map(\.title), ["a.jpg"])
        XCTAssertEqual(publishedFiles("thumbs"), Set(foreign + ["\(index.photos[0].id).jpg"]))
    }

    func testPartiallyMissingOutputIsRegenerated() throws {
        let image = source("a.jpg")
        try export([image])
        let photo = try TVTestSupport.readIndex(libraryDir).photos[0]
        try FileManager.default.removeItem(at: libraryDir.appendingPathComponent(photo.thumb))

        let report = try export([image])
        XCTAssertEqual(report.exported, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: libraryDir.appendingPathComponent(photo.thumb).path))
    }

    func testChangingOptionsRegeneratesEverything() throws {
        let images = [source("a.jpg", width: 800, height: 600)]
        try export(images)
        var bigger = options
        bigger.fullFitBox = TVPixelBox(width: 512, height: 512)
        let report = try export(images, options: bigger)
        XCTAssertEqual(report.exported, 1)
        XCTAssertEqual(report.removed, 2)
        XCTAssertEqual(try TVTestSupport.readIndex(libraryDir).photos[0].width, 512)
    }

    // MARK: - Size presets

    func testFitKeepsAspectRatioInsideBoxAndNeverUpscales() {
        let box = TVExportOptions.fullHDBox
        func fit(_ w: Int, _ h: Int) -> TVPixelBox { TVExportService.fit(TVPixelBox(width: w, height: h), in: box) }
        XCTAssertEqual(fit(6000, 4000), TVPixelBox(width: 1620, height: 1080))   // 3:2
        XCTAssertEqual(fit(4000, 3000), TVPixelBox(width: 1440, height: 1080))   // 4:3
        XCTAssertEqual(fit(3840, 2160), TVPixelBox(width: 1920, height: 1080))   // 16:9
        XCTAssertEqual(fit(4000, 6000), TVPixelBox(width: 720, height: 1080))    // portrait
        XCTAssertEqual(fit(6000, 2000), TVPixelBox(width: 1920, height: 640))    // panorama
        XCTAssertEqual(fit(800, 600), TVPixelBox(width: 800, height: 600))       // already small
    }

    func testFullHDPresetFitsInside1920x1080() throws {
        try export(
            [source("landscape.jpg", width: 2400, height: 1600), source("portrait.jpg", width: 1600, height: 2400)],
            options: .preset(.fullHD)
        )
        let photos = try TVTestSupport.readIndex(libraryDir).photos
        XCTAssertEqual(photos.map(\.width), [1620, 720])
        XCTAssertEqual(photos.map(\.height), [1080, 1080])
        let full = TVTestSupport.cgImage(at: libraryDir.appendingPathComponent(photos[0].full))!
        XCTAssertEqual(full.width, 1620)
        XCTAssertEqual(full.height, 1080)
        XCTAssertEqual(full.colorSpace?.name, CGColorSpace.sRGB)
        let thumb = TVTestSupport.cgImage(at: libraryDir.appendingPathComponent(photos[0].thumb))!
        XCTAssertEqual(thumb.width, 480)
    }

    func testFullHDPresetAppliesOrientationBeforeFitting() throws {
        // Stored 2400×1600 with orientation 6 displays as 1600×2400 portrait.
        try export([source("rotated.jpg", width: 2400, height: 1600, orientation: 6)], options: .preset(.fullHD))
        let photo = try TVTestSupport.readIndex(libraryDir).photos[0]
        XCTAssertEqual(photo.width, 720)
        XCTAssertEqual(photo.height, 1080)
    }

    func testOriginalPresetKeepsSourceResolutionAndStripsMetadata() throws {
        try export([source("big.jpg", width: 2400, height: 1600, date: "2024:06:01 15:22:00", gps: true)], options: .preset(.original))
        let photo = try TVTestSupport.readIndex(libraryDir).photos[0]
        XCTAssertEqual(photo.width, 2400)
        XCTAssertEqual(photo.height, 1600)
        let props = TVTestSupport.properties(of: libraryDir.appendingPathComponent(photo.full))
        XCTAssertNil(props[kCGImagePropertyGPSDictionary])
        XCTAssertEqual(TVTestSupport.cgImage(at: libraryDir.appendingPathComponent(photo.thumb))?.width, 480)
    }

    func testSharpeningChangesPixelsButNotSizeOrColorSpace() throws {
        let image = source("detail.jpg", width: 600, height: 400)
        var plain = options
        plain.fullFitBox = nil
        var sharp = plain
        sharp.sharpen = true

        try export([image], options: plain)
        let plainPhoto = try TVTestSupport.readIndex(libraryDir).photos[0]
        let plainData = try Data(contentsOf: libraryDir.appendingPathComponent(plainPhoto.full))

        try export([image], options: sharp)
        let sharpPhoto = try TVTestSupport.readIndex(libraryDir).photos[0]
        XCTAssertNotEqual(plainPhoto.id, sharpPhoto.id)
        XCTAssertEqual(sharpPhoto.width, 600)
        XCTAssertEqual(sharpPhoto.height, 400)
        let sharpURL = libraryDir.appendingPathComponent(sharpPhoto.full)
        XCTAssertNotEqual(try Data(contentsOf: sharpURL), plainData)
        XCTAssertEqual(TVTestSupport.cgImage(at: sharpURL)?.colorSpace?.name, CGColorSpace.sRGB)
    }

    func testPresetsHaveDistinctProfileKeys() {
        let fullHD = TVExportOptions.preset(.fullHD)
        let original = TVExportOptions.preset(.original)
        XCTAssertEqual(fullHD.fullFitBox, TVExportOptions.fullHDBox)
        XCTAssertTrue(fullHD.sharpen)
        XCTAssertNil(original.fullFitBox)
        XCTAssertFalse(original.sharpen)
        XCTAssertEqual(fullHD.profileKey, "v2-t480-f1920x1080-s1-q92")
        XCTAssertEqual(original.profileKey, "v2-t480-forig-s0-q92")
    }

    // MARK: - Ids, progress, concurrency

    func testPhotoIDIsDeterministicAndSensitiveToInputs() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let id = TVExportService.photoID(path: "/a.jpg", size: 10, modificationDate: date, options: options)
        XCTAssertEqual(id, TVExportService.photoID(path: "/a.jpg", size: 10, modificationDate: date, options: options))
        XCTAssertEqual(id.count, 16)
        XCTAssertTrue(TVExportService.isPublishedFileName("\(id).jpg"))
        XCTAssertNotEqual(id, TVExportService.photoID(path: "/b.jpg", size: 10, modificationDate: date, options: options))
        XCTAssertNotEqual(id, TVExportService.photoID(path: "/a.jpg", size: 11, modificationDate: date, options: options))
        XCTAssertNotEqual(id, TVExportService.photoID(path: "/a.jpg", size: 10, modificationDate: date.addingTimeInterval(1), options: options))
        XCTAssertNotEqual(id, TVExportService.photoID(path: "/a.jpg", size: 10, modificationDate: date, options: TVExportOptions()))
    }

    func testIsPublishedFileName() {
        XCTAssertTrue(TVExportService.isPublishedFileName("0123456789abcdef.jpg"))
        XCTAssertFalse(TVExportService.isPublishedFileName("0123456789ABCDEF.jpg"))
        XCTAssertFalse(TVExportService.isPublishedFileName("0123456789abcde.jpg"))
        XCTAssertFalse(TVExportService.isPublishedFileName("0123456789abcdef.jpeg"))
        XCTAssertFalse(TVExportService.isPublishedFileName("0123456789abcdeg.jpg"))
        XCTAssertFalse(TVExportService.isPublishedFileName("index.json"))
    }

    func testProgressReachesTotalForManyImages() throws {
        let images = (0..<24).map { source("img\($0).jpg", width: 120, height: 80) }
        let lock = NSLock()
        var calls: [Int] = []
        let report = try TVExportService.export(images: images, albumName: "T", to: libraryDir, options: options) { done, total in
            XCTAssertEqual(total, 24)
            lock.lock(); calls.append(done); lock.unlock()
        }
        XCTAssertEqual(report.exported, 24)
        XCTAssertEqual(calls.count, 24)
        XCTAssertEqual(Set(calls), Set(1...24))
        XCTAssertEqual(try TVTestSupport.readIndex(libraryDir).photos.map(\.title), images.map(\.fileName))
    }

    func testReportSummary() {
        var report = TVExportReport(exported: 2, reused: 3)
        XCTAssertEqual(report.summary, "5 photo(s) published (2 new, 3 unchanged)")
        report.removed = 1
        report.missing = ["/x"]
        report.failed = [TVExportFailure(path: "/y", reason: "bad")]
        XCTAssertEqual(report.summary, "5 photo(s) published (2 new, 3 unchanged), 1 stale file(s) removed, 1 missing, 1 failed")
    }
}
