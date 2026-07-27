import Foundation
import SwiftUI
import AppKit

/// Drives the multi-step "Upload from memory card" flow.
@MainActor
final class MemCardImportViewModel: ObservableObject {
    enum Phase {
        case detecting
        case noCard
        case selectCard
        case scanning
        case review
        case copying
        case finished
        case error
    }

    /// A candidate destination folder derived from where album images already live.
    struct FolderOption: Identifiable, Hashable {
        let id = UUID()
        let url: URL
        let count: Int
        var name: String { url.lastPathComponent }
        var path: String { url.path }
    }

    @Published var phase: Phase = .detecting
    @Published var cards: [MemoryCard] = []
    @Published var selectedCard: MemoryCard?

    @Published var totalOnCard = 0
    @Published var newFiles: [URL] = []
    @Published var latestSyncedName: String?

    @Published var folderOptions: [FolderOption] = []
    @Published var selectedFolder: FolderOption?

    @Published var copiedCount = 0
    @Published var errorMessage: String?

    private weak var album: AlbumViewModel?

    var newFileCount: Int { newFiles.count }

    /// True while a copy is in progress (possibly running in the background).
    var isCopying: Bool { phase == .copying }

    /// Copy progress as a whole-number percentage.
    var progressPercent: Int {
        guard newFileCount > 0 else { return 0 }
        return Int((Double(copiedCount) / Double(newFileCount)) * 100)
    }

    // MARK: - Step 1: detect

    /// Start (or restart) the flow. A copy already running in the background is left untouched.
    func begin(album: AlbumViewModel) {
        self.album = album
        guard phase != .copying else { return }
        rescan()
    }

    func rescan() {
        phase = .detecting
        Task { await detect() }
    }

    private func detect() async {
        let found = await Task.detached(priority: .userInitiated) {
            MemoryCardService.detectCards()
        }.value
        cards = found
        if found.isEmpty {
            phase = .noCard
        } else {
            selectedCard = found.first
            phase = .selectCard
        }
    }

    // MARK: - Step 2: confirm card, then scan

    func confirmCard() {
        guard selectedCard != nil else { return }
        phase = .scanning
        Task { await scan() }
    }

    private func scan() async {
        guard let card = selectedCard, let album else {
            fail("No memory card selected.")
            return
        }

        let cardURL = card.url
        let files = await Task.detached(priority: .userInitiated) {
            MemoryCardService.imageFiles(on: cardURL)
        }.value
        totalOnCard = files.count

        // Snapshot album files that share a name with something on the card, together with
        // their sizes. Matching on name+size avoids false positives from cameras (like Nikon)
        // that reuse filenames such as DSC_0670.JPG across different shoots.
        let cardNames = Set(files.map { $0.lastPathComponent.lowercased() })
        let albumMatches: [AlbumFileRef] = album.images.compactMap { image in
            let name = image.fileName.lowercased()
            guard cardNames.contains(name) else { return nil }
            return AlbumFileRef(name: name, size: album.metadata[image.id]?.fileSize, path: image.path)
        }

        let result = await Task.detached(priority: .userInitiated) {
            Self.classify(cardFiles: files, albumMatches: albumMatches)
        }.value

        latestSyncedName = result.latestSyncedName
        newFiles = result.newFiles

        folderOptions = Self.computeFolders(from: album.images)
        selectedFolder = folderOptions.first
        phase = .review
    }

    /// A lightweight, Sendable snapshot of one album image used for sync matching.
    private struct AlbumFileRef: Sendable {
        let name: String       // lowercased filename
        let size: Int64?       // cached size if known
        let path: String       // for a fallback stat
    }

    private struct ScanOutcome: Sendable {
        let latestSyncedName: String?
        let newFiles: [URL]
    }

    /// Determine which card files are new, ordered by **date taken** (EXIF DateTimeOriginal,
    /// falling back to file modification date).
    ///
    /// Already-synced card files are identified by filename + byte size (robust against
    /// cameras that reuse filenames). The most recent synced file — by capture date — marks
    /// the boundary; every card file captured after it is considered new.
    private nonisolated static func classify(
        cardFiles: [URL],
        albumMatches: [AlbumFileRef]
    ) -> ScanOutcome {
        // Map lowercased name -> set of sizes present in the album.
        var albumSizes: [String: Set<Int64>] = [:]
        for ref in albumMatches {
            let size = ref.size ?? fileSize(atPath: ref.path)
            if let size {
                albumSizes[ref.name, default: []].insert(size)
            }
        }

        struct Entry {
            let url: URL
            let date: Date
            let synced: Bool
        }

        var entries: [Entry] = []
        entries.reserveCapacity(cardFiles.count)
        for url in cardFiles {
            let name = url.lastPathComponent.lowercased()
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let size = values?.fileSize.map { Int64($0) }
            let modDate = values?.contentModificationDate
            let captureDate = ExifService.readExifData(from: url.path)?.dateTimeOriginal
                ?? modDate
                ?? Date.distantPast
            let synced = size.map { albumSizes[name]?.contains($0) ?? false } ?? false
            entries.append(Entry(url: url, date: captureDate, synced: synced))
        }

        let latestSynced = entries.filter { $0.synced }.max { $0.date < $1.date }

        let newEntries: [Entry]
        if let boundary = latestSynced?.date {
            newEntries = entries.filter { !$0.synced && $0.date > boundary }
        } else {
            newEntries = entries.filter { !$0.synced }
        }

        let ordered = newEntries.sorted { $0.date < $1.date }.map { $0.url }
        return ScanOutcome(latestSyncedName: latestSynced?.url.lastPathComponent, newFiles: ordered)
    }

    private nonisolated static func fileSize(atPath path: String) -> Int64? {
        (try? FileManager.default.attributesOfItem(atPath: path))?[.size] as? Int64
    }

    /// The 5 folders that hold the most album images.
    private static func computeFolders(from images: [ImageFile]) -> [FolderOption] {
        var counts: [String: Int] = [:]
        for image in images {
            let dir = URL(fileURLWithPath: image.path).deletingLastPathComponent().path
            counts[dir, default: 0] += 1
        }
        return counts
            .filter { FileManager.default.fileExists(atPath: $0.key) }
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { FolderOption(url: URL(fileURLWithPath: $0.key), count: $0.value) }
    }

    // MARK: - Step 3: choose destination

    func chooseCustomFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        panel.message = "Choose a destination folder for imported photos"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        if let existing = folderOptions.first(where: { $0.url == url }) {
            selectedFolder = existing
        } else {
            let option = FolderOption(url: url, count: 0)
            folderOptions.append(option)
            selectedFolder = option
        }
    }

    // MARK: - Step 4: copy + add to album

    func startCopy() {
        guard let destination = selectedFolder?.url, !newFiles.isEmpty else { return }
        phase = .copying
        copiedCount = 0
        Task { await copyAll(to: destination) }
    }

    private func copyAll(to destination: URL) async {
        guard let album else {
            fail("Album is unavailable.")
            return
        }

        let fm = FileManager.default
        try? fm.createDirectory(at: destination, withIntermediateDirectories: true)

        var firstImportedPath: String?

        for file in newFiles {
            let destURL = Self.uniqueDestination(for: file, in: destination, fm: fm)
            do {
                try fm.copyItem(at: file, to: destURL)
                await album.importCopiedFile(at: destURL.path)
                if firstImportedPath == nil {
                    firstImportedPath = destURL.path
                }
                copiedCount += 1
            } catch {
                log("❌ MemCard: failed to copy \(file.lastPathComponent): \(error)")
            }
        }

        await album.finishImport()

        if let path = firstImportedPath,
           let index = album.images.firstIndex(where: { $0.path == path }) {
            album.selectImage(at: index)
            log("🎯 MemCard: Focused first import \(URL(fileURLWithPath: path).lastPathComponent) at index \(index)")
        }

        phase = .finished
    }

    private static func uniqueDestination(for file: URL, in folder: URL, fm: FileManager) -> URL {
        var dest = folder.appendingPathComponent(file.lastPathComponent)
        let base = dest.deletingPathExtension().lastPathComponent
        let ext = dest.pathExtension
        var counter = 1
        while fm.fileExists(atPath: dest.path) {
            let name = ext.isEmpty ? "\(base)_\(counter)" : "\(base)_\(counter).\(ext)"
            dest = folder.appendingPathComponent(name)
            counter += 1
        }
        return dest
    }

    private func fail(_ message: String) {
        errorMessage = message
        phase = .error
    }
}
