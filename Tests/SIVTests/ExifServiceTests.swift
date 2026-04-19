import XCTest
import ImageIO
import CoreGraphics
@testable import SIV

final class ExifServiceTests: XCTestCase {
    var tempDir: URL!
    var testImagePath: String!
    
    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ExifServiceTests-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        testImagePath = createTestJPEG(
            name: "test.jpg",
            exifDate: "2024:06:15 14:30:00",
            cameraMake: "TestCamera",
            cameraModel: "TestModel",
            latitude: 48.8566, latRef: "N",
            longitude: 2.3522, lonRef: "E",
            altitude: 35.0
        )
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }
    
    // MARK: - Read Tests
    
    func testReadExifData() {
        let data = ExifService.readExifData(from: testImagePath)
        XCTAssertNotNil(data)
        XCTAssertEqual(data?.pixelWidth, 100)
        XCTAssertEqual(data?.pixelHeight, 100)
        XCTAssertEqual(data?.cameraMake, "TestCamera")
        XCTAssertEqual(data?.cameraModel, "TestModel")
    }
    
    func testReadDate() {
        let data = ExifService.readExifData(from: testImagePath)
        XCTAssertNotNil(data?.dateTimeOriginal)
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute],
                                                  from: data!.dateTimeOriginal!)
        XCTAssertEqual(components.year, 2024)
        XCTAssertEqual(components.month, 6)
        XCTAssertEqual(components.day, 15)
    }
    
    func testReadGPS() {
        let data = ExifService.readExifData(from: testImagePath)
        XCTAssertEqual(data?.latitude ?? 0, 48.8566, accuracy: 0.001)
        XCTAssertEqual(data?.longitude ?? 0, 2.3522, accuracy: 0.001)
        XCTAssertEqual(data?.altitude ?? 0, 35.0, accuracy: 0.1)
    }
    
    func testReadSouthernHemisphere() {
        let path = createTestJPEG(
            name: "south.jpg",
            latitude: 33.8688, latRef: "S",
            longitude: 151.2093, lonRef: "E"
        )
        let data = ExifService.readExifData(from: path)
        XCTAssertEqual(data?.latitude ?? 0, -33.8688, accuracy: 0.001)
        XCTAssertEqual(data?.longitude ?? 0, 151.2093, accuracy: 0.001)
    }
    
    func testReadWesternHemisphere() {
        let path = createTestJPEG(
            name: "west.jpg",
            latitude: 40.7128, latRef: "N",
            longitude: 74.006, lonRef: "W"
        )
        let data = ExifService.readExifData(from: path)
        XCTAssertEqual(data?.longitude ?? 0, -74.006, accuracy: 0.001)
    }
    
    func testReadNonexistentFile() {
        let data = ExifService.readExifData(from: "/nonexistent/file.jpg")
        XCTAssertNil(data)
    }
    
    func testReadNoExifImage() {
        let path = createTestJPEG(name: "bare.jpg")
        let data = ExifService.readExifData(from: path)
        XCTAssertNotNil(data)
        XCTAssertEqual(data?.pixelWidth, 100)
        XCTAssertNil(data?.dateTimeOriginal)
        XCTAssertNil(data?.latitude)
        XCTAssertNil(data?.cameraMake)
    }
    
    // MARK: - Write Date Tests
    
    func testWriteDate() throws {
        let newDate = Date(timeIntervalSince1970: 1_700_000_000)
        try ExifService.writeDate(newDate, to: testImagePath)
        
        let data = ExifService.readExifData(from: testImagePath)
        XCTAssertNotNil(data?.dateTimeOriginal)
        let diff = abs(data!.dateTimeOriginal!.timeIntervalSince(newDate))
        XCTAssertLessThan(diff, 1.0)
    }
    
    func testWriteDatePreservesOtherMetadata() throws {
        try ExifService.writeDate(Date(), to: testImagePath)
        
        let data = ExifService.readExifData(from: testImagePath)
        XCTAssertEqual(data?.cameraMake, "TestCamera")
        XCTAssertEqual(data?.latitude ?? 0, 48.8566, accuracy: 0.001)
        XCTAssertEqual(data?.pixelWidth, 100)
    }
    
    func testWriteDateToNonexistentFile() {
        XCTAssertThrowsError(try ExifService.writeDate(Date(), to: "/nonexistent/file.jpg"))
    }
    
    // MARK: - Write Location Tests
    
    func testWriteLocation() throws {
        try ExifService.writeLocation(latitude: 40.7128, longitude: -74.006, altitude: 10.0, to: testImagePath)
        
        let data = ExifService.readExifData(from: testImagePath)
        XCTAssertEqual(data?.latitude ?? 0, 40.7128, accuracy: 0.001)
        XCTAssertEqual(data?.longitude ?? 0, -74.006, accuracy: 0.001)
        XCTAssertEqual(data?.altitude ?? 0, 10.0, accuracy: 0.1)
    }
    
    func testWriteLocationPreservesDate() throws {
        let dateBefore = ExifService.readExifData(from: testImagePath)?.dateTimeOriginal
        
        try ExifService.writeLocation(latitude: 0, longitude: 0, to: testImagePath)
        
        let dataAfter = ExifService.readExifData(from: testImagePath)
        XCTAssertEqual(dateBefore, dataAfter?.dateTimeOriginal)
    }
    
    func testRemoveLocation() throws {
        var data = ExifService.readExifData(from: testImagePath)
        XCTAssertNotNil(data?.latitude)
        
        try ExifService.removeLocation(from: testImagePath)
        
        data = ExifService.readExifData(from: testImagePath)
        XCTAssertNil(data?.latitude)
        XCTAssertNil(data?.longitude)
        // Camera data should still be there
        XCTAssertEqual(data?.cameraMake, "TestCamera")
    }
    
    // MARK: - Batch Timestamp Delta Tests
    
    func testApplyTimestampDelta() throws {
        let paths = (0..<3).map { i -> String in
            let dest = tempDir.appendingPathComponent("delta_\(i).jpg").path
            try! FileManager.default.copyItem(atPath: testImagePath, toPath: dest)
            return dest
        }
        
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
        try ExifService.applyTimestampDelta(to: paths, baseDate: baseDate, deltaSeconds: 60)
        
        for (index, path) in paths.enumerated() {
            let data = ExifService.readExifData(from: path)
            XCTAssertNotNil(data?.dateTimeOriginal, "File \(index) should have a date")
            let expectedDate = baseDate.addingTimeInterval(Double(index) * 60)
            let diff = abs(data!.dateTimeOriginal!.timeIntervalSince(expectedDate))
            XCTAssertLessThan(diff, 1.0, "File \(index): expected \(expectedDate), got \(data!.dateTimeOriginal!)")
        }
    }
    
    func testApplyTimestampDeltaOrder() throws {
        let paths = (0..<5).map { i -> String in
            let dest = tempDir.appendingPathComponent("order_\(i).jpg").path
            try! FileManager.default.copyItem(atPath: testImagePath, toPath: dest)
            return dest
        }
        
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
        try ExifService.applyTimestampDelta(to: paths, baseDate: baseDate, deltaSeconds: 1)
        
        var previousDate: Date?
        for path in paths {
            let data = ExifService.readExifData(from: path)!
            if let prev = previousDate {
                XCTAssertGreaterThan(data.dateTimeOriginal!, prev,
                                     "Timestamps must be strictly increasing")
            }
            previousDate = data.dateTimeOriginal
        }
    }
    
    // MARK: - ExifData Formatting Tests
    
    func testShutterSpeedFormatted() {
        var data = ExifData()
        data.shutterSpeed = 1.0 / 60.0
        XCTAssertEqual(data.shutterSpeedFormatted, "1/60 s")
        
        data.shutterSpeed = 2.0
        XCTAssertEqual(data.shutterSpeedFormatted, "2.0 s")
        
        data.shutterSpeed = nil
        XCTAssertNil(data.shutterSpeedFormatted)
    }
    
    func testApertureFormatted() {
        var data = ExifData()
        data.aperture = 2.8
        XCTAssertEqual(data.apertureFormatted, "f/2.8")
    }
    
    func testLocationFormatted() {
        var data = ExifData()
        data.latitude = 48.8566
        data.longitude = 2.3522
        data.altitude = 35.0
        XCTAssertTrue(data.locationFormatted!.contains("48.856600"))
        XCTAssertTrue(data.locationFormatted!.contains("N"))
        XCTAssertTrue(data.locationFormatted!.contains("35.0 m"))
        
        data.latitude = nil
        XCTAssertNil(data.locationFormatted)
    }
    
    // MARK: - Integration: Default Album Images
    
    func testReadFromDefaultAlbum() throws {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        let albumPath = appSupport.appendingPathComponent("SIV/default.sivalb").path
        
        guard FileManager.default.fileExists(atPath: albumPath),
              let albumData = try? Data(contentsOf: URL(fileURLWithPath: albumPath)),
              let album = try? JSONDecoder().decode(Album.self, from: albumData) else {
            throw XCTSkip("No default album available")
        }
        
        let existingImages = album.images.filter { $0.exists }
        guard !existingImages.isEmpty else {
            throw XCTSkip("No existing images in default album")
        }
        
        for image in existingImages.prefix(5) {
            let data = ExifService.readExifData(from: image.path)
            XCTAssertNotNil(data, "Failed to read EXIF from \(image.fileName)")
            XCTAssertNotNil(data?.pixelWidth, "No pixel width for \(image.fileName)")
            XCTAssertNotNil(data?.pixelHeight, "No pixel height for \(image.fileName)")
            print("📷 \(image.fileName): \(data?.pixelWidth ?? 0)×\(data?.pixelHeight ?? 0), " +
                  "date=\(data?.dateTimeOriginal?.description ?? "none"), " +
                  "camera=\(data?.cameraModel ?? "none"), " +
                  "location=\(data?.locationFormatted ?? "none")")
        }
    }
    
    // MARK: - Test Helper
    
    @discardableResult
    private func createTestJPEG(
        name: String,
        exifDate: String? = nil,
        cameraMake: String? = nil,
        cameraModel: String? = nil,
        latitude: Double? = nil, latRef: String? = nil,
        longitude: Double? = nil, lonRef: String? = nil,
        altitude: Double? = nil
    ) -> String {
        let width = 100, height = 100
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let cgImage = context.makeImage()!
        
        let path = tempDir.appendingPathComponent(name)
        let destination = CGImageDestinationCreateWithURL(
            path as CFURL, "public.jpeg" as CFString, 1, nil
        )!
        
        var properties: [String: Any] = [:]
        
        if exifDate != nil || cameraMake != nil || cameraModel != nil {
            var exifDict: [String: Any] = [:]
            if let d = exifDate {
                exifDict[kCGImagePropertyExifDateTimeOriginal as String] = d
                exifDict[kCGImagePropertyExifDateTimeDigitized as String] = d
            }
            properties[kCGImagePropertyExifDictionary as String] = exifDict
            
            var tiffDict: [String: Any] = [:]
            if let make = cameraMake { tiffDict[kCGImagePropertyTIFFMake as String] = make }
            if let model = cameraModel { tiffDict[kCGImagePropertyTIFFModel as String] = model }
            if !tiffDict.isEmpty {
                properties[kCGImagePropertyTIFFDictionary as String] = tiffDict
            }
        }
        
        if let lat = latitude, let latR = latRef, let lon = longitude, let lonR = lonRef {
            var gpsDict: [String: Any] = [
                kCGImagePropertyGPSLatitude as String: lat,
                kCGImagePropertyGPSLatitudeRef as String: latR,
                kCGImagePropertyGPSLongitude as String: lon,
                kCGImagePropertyGPSLongitudeRef as String: lonR,
            ]
            if let alt = altitude {
                gpsDict[kCGImagePropertyGPSAltitude as String] = alt
                gpsDict[kCGImagePropertyGPSAltitudeRef as String] = 0
            }
            properties[kCGImagePropertyGPSDictionary as String] = gpsDict
        }
        
        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        CGImageDestinationFinalize(destination)
        
        return path.path
    }
}
