import Foundation
import CoreGraphics

/// Represents an image file with its metadata
struct ImageFile: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let filename: String
    let fileSize: Int64
    var dimensions: CGSize?
    let createdDate: Date
    let format: ImageFormat?
    
    init(url: URL) throws {
        self.id = UUID()
        self.url = url
        self.filename = url.lastPathComponent
        
        // Get file attributes
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        self.fileSize = attributes[.size] as? Int64 ?? 0
        self.createdDate = attributes[.creationDate] as? Date ?? Date()
        
        // Detect format from extension
        self.format = ImageFormat(rawValue: url.pathExtension.uppercased())
    }
    
    static func == (lhs: ImageFile, rhs: ImageFile) -> Bool {
        lhs.id == rhs.id
    }
}

/// Supported image formats
enum ImageFormat: String, CaseIterable {
    case jpeg = "JPEG"
    case jpg = "JPG"
    case png = "PNG"
    case heif = "HEIF"
    case heic = "HEIC"
    
    static var supportedExtensions: [String] {
        return allCases.map { $0.rawValue.lowercased() }
    }
    
    var displayName: String {
        switch self {
        case .jpeg, .jpg:
            return "JPEG"
        case .png:
            return "PNG"
        case .heif, .heic:
            return "HEIF"
        }
    }
}

