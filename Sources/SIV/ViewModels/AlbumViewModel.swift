import Foundation
import SwiftUI
import Combine

enum AlbumViewMode: String, CaseIterable {
    case thumbnails = "Thumbnails"
    case list = "List"
}

@MainActor
class AlbumViewModel: ObservableObject {
    @Published var albumManager = AlbumManager()
    @Published var selectedIndices: Set<Int> = []
    @Published var lastClickedIndex: Int?
    @Published var viewMode: AlbumViewMode = .list
    @Published var showMissingFilesDialog: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        albumManager.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.objectWillChange.send()
            }
        }
        .store(in: &cancellables)
    }
    
    func initialize() async {
        print("🚀 AlbumViewModel: Initializing...")
        await albumManager.loadDefaultAlbum()
        print("✅ AlbumViewModel: Loaded album with \(images.count) images")
        
        if albumManager.hasMissingFiles {
            showMissingFilesDialog = true
        }
    }
    
    var album: Album? {
        albumManager.currentAlbum
    }
    
    var images: [ImageFile] {
        album?.images ?? []
    }
    
    // MARK: - Adding Images
    
    private static let supportedExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "tiff", "tif", "gif", "bmp", "webp"
    ]
    
    func addImages(_ paths: [String]) async {
        let resolvedPaths = paths.flatMap { expandPath($0) }
        print("📸 AlbumViewModel: Adding \(resolvedPaths.count) images to album (from \(paths.count) dropped items)")
        await albumManager.addImages(resolvedPaths)
        print("✅ AlbumViewModel: Album now has \(images.count) images")
    }
    
    private func expandPath(_ path: String) -> [String] {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir) else { return [] }
        
        if !isDir.boolValue {
            return [path]
        }
        
        guard let enumerator = FileManager.default.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        
        var result: [String] = []
        for case let fileURL as URL in enumerator {
            if Self.supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
                result.append(fileURL.path)
            }
        }
        result.sort()
        return result
    }
    
    func addImage(_ path: String) async {
        await addImages([path])
    }
    
    // MARK: - Selection
    
    /// The index of the image to display in the canvas
    var primarySelectedIndex: Int? {
        if let last = lastClickedIndex, selectedIndices.contains(last), last < images.count {
            return last
        }
        return selectedIndices.sorted().first
    }
    
    var selectedImage: ImageFile? {
        guard let index = primarySelectedIndex, index < images.count else { return nil }
        return images[index]
    }
    
    /// Selected image files in album order
    var selectedImageFiles: [ImageFile] {
        selectedIndices.sorted().compactMap { idx in
            idx < images.count ? images[idx] : nil
        }
    }
    
    func handleClick(at index: Int, cmd: Bool, shift: Bool) {
        guard index >= 0 && index < images.count else { return }
        
        if shift, let anchor = lastClickedIndex {
            let range = Set(min(anchor, index)...max(anchor, index))
            if cmd {
                selectedIndices.formUnion(range)
            } else {
                selectedIndices = range
            }
        } else if cmd {
            if selectedIndices.contains(index) {
                selectedIndices.remove(index)
            } else {
                selectedIndices.insert(index)
            }
            lastClickedIndex = index
        } else {
            selectedIndices = [index]
            lastClickedIndex = index
        }
    }
    
    func selectImage(at index: Int) {
        guard index >= 0 && index < images.count else { return }
        selectedIndices = [index]
        lastClickedIndex = index
    }
    
    func selectNextImage() {
        guard !images.isEmpty else { return }
        let current = lastClickedIndex ?? -1
        let next = min(current + 1, images.count - 1)
        selectedIndices = [next]
        lastClickedIndex = next
    }
    
    func selectPreviousImage() {
        guard !images.isEmpty else { return }
        let current = lastClickedIndex ?? images.count
        let prev = max(current - 1, 0)
        selectedIndices = [prev]
        lastClickedIndex = prev
    }
    
    // MARK: - Removal
    
    func removeImage(at index: Int) async {
        await albumManager.removeImage(at: index)
        adjustSelectionAfterRemoval(of: Set([index]))
    }
    
    func removeSelectedImages() async {
        guard !selectedIndices.isEmpty else { return }
        await albumManager.removeImages(at: selectedIndices)
        selectedIndices.removeAll()
        lastClickedIndex = nil
    }
    
    private func adjustSelectionAfterRemoval(of removed: Set<Int>) {
        var newSelection = Set<Int>()
        for idx in selectedIndices where !removed.contains(idx) {
            let offset = removed.filter { $0 < idx }.count
            newSelection.insert(idx - offset)
        }
        selectedIndices = newSelection
        if let last = lastClickedIndex {
            if removed.contains(last) {
                lastClickedIndex = newSelection.sorted().first
            } else {
                let offset = removed.filter { $0 < last }.count
                lastClickedIndex = last - offset
            }
        }
    }
    
    func removeMissingFiles() async {
        _ = await albumManager.removeMissingFiles()
        selectedIndices.removeAll()
        lastClickedIndex = nil
        showMissingFilesDialog = false
    }
    
    // MARK: - Export
    
    func exportSelectedImages() {
        let imagesToExport = selectedIndices.sorted().compactMap { idx -> ImageFile? in
            idx < images.count ? images[idx] : nil
        }
        guard !imagesToExport.isEmpty else { return }
        
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Export"
        panel.message = "Choose a folder to export \(imagesToExport.count) image(s)"
        
        guard panel.runModal() == .OK, let destinationURL = panel.url else { return }
        
        let fm = FileManager.default
        var exported = 0
        for image in imagesToExport {
            let sourceURL = URL(fileURLWithPath: image.path)
            var destURL = destinationURL.appendingPathComponent(image.fileName)
            
            var counter = 1
            let baseName = destURL.deletingPathExtension().lastPathComponent
            let ext = destURL.pathExtension
            while fm.fileExists(atPath: destURL.path) {
                destURL = destinationURL.appendingPathComponent("\(baseName)_\(counter).\(ext)")
                counter += 1
            }
            
            do {
                try fm.copyItem(at: sourceURL, to: destURL)
                exported += 1
            } catch {
                print("❌ Export failed for \(image.fileName): \(error.localizedDescription)")
            }
        }
        print("✅ Exported \(exported)/\(imagesToExport.count) images to \(destinationURL.path)")
    }
    
    // MARK: - File Picker
    
    func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.jpeg, .png, .heic, .tiff, .gif, .bmp, .image, .folder]
        
        if panel.runModal() == .OK {
            let paths = panel.urls.map { $0.path }
            Task {
                await addImages(paths)
            }
        }
    }
    
    var missingFiles: [ImageFile] {
        albumManager.missingFiles
    }
}
