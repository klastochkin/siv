import Foundation

struct ExifData {
    var dateTimeOriginal: Date?
    var dateTimeDigitized: Date?
    
    var cameraMake: String?
    var cameraModel: String?
    var lensModel: String?
    
    var isoSpeed: Int?
    var aperture: Double?
    var shutterSpeed: Double?
    var focalLength: Double?
    
    var latitude: Double?
    var longitude: Double?
    var altitude: Double?
    
    var pixelWidth: Int?
    var pixelHeight: Int?
    var colorSpace: String?
    var orientation: Int?
    
    var shutterSpeedFormatted: String? {
        guard let speed = shutterSpeed else { return nil }
        if speed >= 1 {
            return String(format: "%.1f s", speed)
        } else {
            let denominator = Int(round(1.0 / speed))
            return "1/\(denominator) s"
        }
    }
    
    var apertureFormatted: String? {
        guard let f = aperture else { return nil }
        return String(format: "f/%.1f", f)
    }
    
    var locationFormatted: String? {
        guard let lat = latitude, let lon = longitude else { return nil }
        let latDir = lat >= 0 ? "N" : "S"
        let lonDir = lon >= 0 ? "E" : "W"
        var result = String(format: "%.6f° %@, %.6f° %@", abs(lat), latDir, abs(lon), lonDir)
        if let alt = altitude {
            result += String(format: ", %.1f m", alt)
        }
        return result
    }
}
