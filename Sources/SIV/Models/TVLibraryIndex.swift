import Foundation

/// `index.json` served to the SIV TV app. Paths are relative to the library root.
struct TVLibraryIndex: Codable, Equatable {
    static let currentVersion = 1
    static let fileName = "index.json"

    var version: Int
    var generatedAt: Date
    var albumName: String
    var photos: [TVPhoto]

    init(version: Int = TVLibraryIndex.currentVersion, generatedAt: Date = Date(), albumName: String, photos: [TVPhoto]) {
        self.version = version
        self.generatedAt = generatedAt
        self.albumName = albumName
        self.photos = photos
    }

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

struct TVPhoto: Codable, Equatable {
    var id: String
    var title: String
    var takenAt: Date?
    var thumb: String
    var full: String
    var width: Int
    var height: Int
}
