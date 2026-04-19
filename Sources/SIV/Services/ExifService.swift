import Foundation
import ImageIO

enum ExifError: LocalizedError {
    case cannotReadFile
    case unknownImageType
    case cannotCreateDestination
    case writeFailed
    
    var errorDescription: String? {
        switch self {
        case .cannotReadFile: return "Cannot read image file"
        case .unknownImageType: return "Unknown image type"
        case .cannotCreateDestination: return "Cannot create image destination"
        case .writeFailed: return "Failed to write image file"
        }
    }
}

/// Standalone EXIF read/write service using ImageIO.
/// No UI dependencies — designed to be independently testable.
class ExifService {
    
    static let exifDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy:MM:dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
    
    // MARK: - Read
    
    static func readExifData(from path: String) -> ExifData? {
        let url = URL(fileURLWithPath: path)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let rawProps = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return nil
        }
        return parseProperties(rawProps)
    }
    
    static func parseProperties(_ rawProps: [String: Any]) -> ExifData {
        var data = ExifData()
        
        data.pixelWidth = rawProps[kCGImagePropertyPixelWidth as String] as? Int
        data.pixelHeight = rawProps[kCGImagePropertyPixelHeight as String] as? Int
        data.orientation = rawProps[kCGImagePropertyOrientation as String] as? Int
        data.colorSpace = rawProps[kCGImagePropertyColorModel as String] as? String
        
        if let exif = rawProps[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            if let dateStr = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String {
                data.dateTimeOriginal = exifDateFormatter.date(from: dateStr)
            }
            if let dateStr = exif[kCGImagePropertyExifDateTimeDigitized as String] as? String {
                data.dateTimeDigitized = exifDateFormatter.date(from: dateStr)
            }
            if let isoArray = exif[kCGImagePropertyExifISOSpeedRatings as String] as? [Int],
               let iso = isoArray.first {
                data.isoSpeed = iso
            }
            data.aperture = exif[kCGImagePropertyExifFNumber as String] as? Double
            data.shutterSpeed = exif[kCGImagePropertyExifExposureTime as String] as? Double
            data.focalLength = exif[kCGImagePropertyExifFocalLength as String] as? Double
            data.lensModel = exif[kCGImagePropertyExifLensModel as String] as? String
        }
        
        if let tiff = rawProps[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            data.cameraMake = tiff[kCGImagePropertyTIFFMake as String] as? String
            data.cameraModel = tiff[kCGImagePropertyTIFFModel as String] as? String
        }
        
        if let gps = rawProps[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
            if let lat = gps[kCGImagePropertyGPSLatitude as String] as? Double,
               let latRef = gps[kCGImagePropertyGPSLatitudeRef as String] as? String {
                data.latitude = latRef == "S" ? -lat : lat
            }
            if let lon = gps[kCGImagePropertyGPSLongitude as String] as? Double,
               let lonRef = gps[kCGImagePropertyGPSLongitudeRef as String] as? String {
                data.longitude = lonRef == "W" ? -lon : lon
            }
            data.altitude = gps[kCGImagePropertyGPSAltitude as String] as? Double
            if let altRef = gps[kCGImagePropertyGPSAltitudeRef as String] as? Int, altRef == 1 {
                data.altitude = data.altitude.map { -$0 }
            }
        }
        
        return data
    }
    
    // MARK: - Write
    
    /// Write date/time to EXIF (DateTimeOriginal, DateTimeDigitized, TIFF DateTime)
    static func writeDate(_ date: Date, to path: String) throws {
        try writeMetadata(to: path) { properties in
            let dateString = exifDateFormatter.string(from: date)
            
            var exifDict = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
            exifDict[kCGImagePropertyExifDateTimeOriginal as String] = dateString
            exifDict[kCGImagePropertyExifDateTimeDigitized as String] = dateString
            properties[kCGImagePropertyExifDictionary as String] = exifDict
            
            var tiffDict = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
            tiffDict[kCGImagePropertyTIFFDateTime as String] = dateString
            properties[kCGImagePropertyTIFFDictionary as String] = tiffDict
        }
    }
    
    /// Write GPS coordinates to EXIF
    static func writeLocation(latitude: Double, longitude: Double, altitude: Double? = nil, to path: String) throws {
        try writeMetadata(to: path) { properties in
            var gps: [String: Any] = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] ?? [:]
            gps[kCGImagePropertyGPSLatitude as String] = abs(latitude)
            gps[kCGImagePropertyGPSLatitudeRef as String] = latitude >= 0 ? "N" : "S"
            gps[kCGImagePropertyGPSLongitude as String] = abs(longitude)
            gps[kCGImagePropertyGPSLongitudeRef as String] = longitude >= 0 ? "E" : "W"
            
            if let alt = altitude {
                gps[kCGImagePropertyGPSAltitude as String] = abs(alt)
                gps[kCGImagePropertyGPSAltitudeRef as String] = alt >= 0 ? 0 : 1
            }
            
            properties[kCGImagePropertyGPSDictionary as String] = gps
        }
    }
    
    /// Remove GPS data from EXIF
    static func removeLocation(from path: String) throws {
        try writeMetadata(to: path) { properties in
            properties[kCGImagePropertyGPSDictionary as String] = kCFNull
        }
    }
    
    /// Apply incrementing timestamps to ordered files.
    /// File at index i gets: baseDate + (i * deltaSeconds).
    static func applyTimestampDelta(to paths: [String], baseDate: Date, deltaSeconds: TimeInterval) throws {
        for (index, path) in paths.enumerated() {
            let date = baseDate.addingTimeInterval(Double(index) * deltaSeconds)
            try writeDate(date, to: path)
        }
    }
    
    // MARK: - Core write helper
    
    /// Rewrite image file with modified metadata, preserving original encoding.
    static func writeMetadata(to path: String, update: (inout [String: Any]) -> Void) throws {
        let url = URL(fileURLWithPath: path)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw ExifError.cannotReadFile
        }
        
        guard let uti = CGImageSourceGetType(source) else {
            throw ExifError.unknownImageType
        }
        
        var properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] ?? [:]
        update(&properties)
        
        let tempURL = url.deletingLastPathComponent()
            .appendingPathComponent(".\(url.lastPathComponent).exiftmp")
        
        guard let destination = CGImageDestinationCreateWithURL(tempURL as CFURL, uti, 1, nil) else {
            throw ExifError.cannotCreateDestination
        }
        
        CGImageDestinationAddImageFromSource(destination, source, 0, properties as CFDictionary)
        
        guard CGImageDestinationFinalize(destination) else {
            try? FileManager.default.removeItem(at: tempURL)
            throw ExifError.writeFailed
        }
        
        _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL)
    }
}
