import Foundation

/// Captures everything needed to undo a single file deletion.
struct DeleteRecord {
    let originalPath: String
    let trashedURL: URL
    let albumIndex: Int
    let imageId: UUID

    var fileName: String {
        URL(fileURLWithPath: originalPath).lastPathComponent
    }
}
