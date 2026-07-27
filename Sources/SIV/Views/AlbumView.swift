import SwiftUI

struct AlbumView: View {
    @ObservedObject var viewModel: AlbumViewModel
    @ObservedObject var imageViewModel: ImageViewModel
    @ObservedObject var memCardImport: MemCardImportViewModel
    @Binding var showMemCardImport: Bool
    
    @State private var propertiesImageFile: ImageFile?
    @State private var showBatchTimestamp = false
    
    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
        }
        .onChange(of: viewModel.selectedImage) { newImage in
            if let image = newImage {
                log("🖼️ AlbumView: [\(viewModel.viewMode.rawValue)] Selected \(image.fileName) (index \(viewModel.primarySelectedIndex ?? -1) of \(viewModel.images.count))")
                imageViewModel.loadImage(from: image)
                // Prefetch ±2 neighbours in album order at full quality
                imageViewModel.prefetchImages(viewModel.neighboringImages(radius: 2))
            }
        }
        .sheet(item: $propertiesImageFile) { imageFile in
            ExifPropertiesView(imageFile: imageFile)
        }
        .sheet(isPresented: $showBatchTimestamp) {
            BatchTimestampView(imageFiles: viewModel.selectedImageFiles)
        }
        .alert("Missing Files", isPresented: $viewModel.showMissingFilesDialog) {
            Button("Remove All Missing Files") {
                Task { await viewModel.removeMissingFiles() }
            }
            Button("Cancel", role: .cancel) {
                viewModel.showMissingFilesDialog = false
            }
        } message: {
            Text("The following files are missing:\n\n" +
                 viewModel.missingFiles.map { $0.fileName }.joined(separator: "\n"))
        }
    }
    
    // MARK: - Toolbar
    
    private var toolbar: some View {
        HStack {
            Text("Album")
                .font(.headline)
            
            Text("\(viewModel.images.count) images")
                .font(.caption)
                .foregroundColor(.secondary)

            if memCardImport.isCopying {
                Button {
                    showMemCardImport = true
                } label: {
                    HStack(spacing: 4) {
                        ProgressView().controlSize(.mini)
                        Text("copying \(memCardImport.progressPercent)%")
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.accentColor.opacity(0.18)))
                }
                .buttonStyle(.plain)
                .help("Show import progress")
            }
            
            if !viewModel.selectedIndices.isEmpty {
                Text("(\(viewModel.selectedIndices.count) selected)")
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }
            
            Spacer()
            
            if !viewModel.selectedIndices.isEmpty {
                Button(action: { viewModel.exportSelectedImages() }) {
                    Image(systemName: "square.and.arrow.up")
                }
                .buttonStyle(.borderless)
                .help("Export \(viewModel.selectedIndices.count) selected image(s)")
            }
            
            Picker("View Mode", selection: $viewModel.viewMode) {
                ForEach(AlbumViewMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
            
            Button(action: { viewModel.openFilePicker() }) {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var content: some View {
        if viewModel.images.isEmpty {
            emptyState
        } else if viewModel.viewMode == .list {
            listView
                .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    handleDrop(providers: providers)
                    return true
                }
        } else {
            thumbnailView
                .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    handleDrop(providers: providers)
                    return true
                }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            Text("No Images in Album")
                .font(.title3)
                .foregroundColor(.gray)
            Text("Drag & drop images here to add to album")
                .font(.body)
                .foregroundColor(.gray.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
            return true
        }
    }
    
    // MARK: - List View
    
    private var listView: some View {
        // Rows are an Equatable subview keyed on (image, meta), so a selection
        // change no longer re-runs the expensive per-row formatting/tooltip work
        // for all ~1600 rows — only the row background (cheap) updates.
        let indexByID = Dictionary(
            viewModel.images.enumerated().map { ($0.element.id, $0.offset) },
            uniquingKeysWith: { first, _ in first }
        )
        return ScrollViewReader { proxy in
            List {
                ForEach(viewModel.images) { image in
                    let index = indexByID[image.id] ?? 0
                    AlbumListRow(
                        image: image,
                        meta: viewModel.metadata[image.id],
                        onClick: { cmd, shift in
                            viewModel.handleClick(at: index, cmd: cmd, shift: shift)
                        },
                        onOpenPreview: { openInPreview(image) }
                    )
                    .equatable()
                    .listRowBackground(
                        viewModel.selectedIndices.contains(index)
                            ? Color.accentColor.opacity(0.2)
                            : Color.clear
                    )
                    .contextMenu { imageContextMenu(for: index) }
                    .id(image.id)
                }
            }
            .onChange(of: viewModel.lastClickedIndex) { newValue in
                if let index = newValue, index < viewModel.images.count {
                    withAnimation { proxy.scrollTo(viewModel.images[index].id) }
                }
            }
        }
    }
    
    // MARK: - Thumbnail View

    private var thumbnailView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 16) {
                    ForEach(Array(viewModel.images.enumerated()), id: \.element.id) { index, image in
                        VStack {
                            ZStack {
                                if let thumb = viewModel.thumbnails[image.id] {
                                    Image(nsImage: thumb)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 100, height: 100)
                                        .cornerRadius(8)
                                } else {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 100, height: 100)
                                        .cornerRadius(8)
                                        .overlay(
                                            Image(systemName: "photo")
                                                .font(.largeTitle)
                                                .foregroundColor(.gray)
                                        )
                                }
                                
                                if viewModel.metadata[image.id]?.exists == false {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.largeTitle)
                                        .foregroundColor(.red)
                                        .background(Circle().fill(Color.white).padding(6))
                                }
                            }
                            
                            Text(image.fileName)
                                .font(.caption)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .frame(width: 100)
                        }
                        .padding(8)
                        .background(
                            viewModel.selectedIndices.contains(index)
                                ? Color.accentColor.opacity(0.2)
                                : Color.clear
                        )
                        .cornerRadius(8)
                        .task(id: image.id) {
                            await viewModel.loadThumbnail(for: image)
                        }
                        .onTapGesture(count: 2) {
                            openInPreview(image)
                        }
                        .onTapGesture {
                            let flags = NSApp.currentEvent?.modifierFlags ?? []
                            viewModel.handleClick(
                                at: index,
                                cmd: flags.contains(.command),
                                shift: flags.contains(.shift)
                            )
                        }
                        .help(tooltipText(for: image))
                        .contextMenu { imageContextMenu(for: index) }
                        .id(image.id)
                    }
                }
                .padding()
            }
            .background(GeometryReader { geo in
                Color.clear
                    .onAppear { updateThumbnailColumnCount(width: geo.size.width) }
                    .onChange(of: geo.size.width) { updateThumbnailColumnCount(width: $0) }
            })
            .onChange(of: viewModel.lastClickedIndex) { newValue in
                if let index = newValue, index < viewModel.images.count {
                    withAnimation { proxy.scrollTo(viewModel.images[index].id) }
                }
            }
        }
    }
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private func imageContextMenu(for index: Int) -> some View {
        let image = viewModel.images[index]
        let isMultiSelect = viewModel.selectedIndices.count > 1 && viewModel.selectedIndices.contains(index)
        
        Button("Properties...") {
            propertiesImageFile = image
        }

        Button("Reveal in Finder") {
            revealInFinder(image)
        }
        
        Divider()
        
        if isMultiSelect {
            Button("Set Timestamps...") {
                showBatchTimestamp = true
            }
            
            Button("Export \(viewModel.selectedIndices.count) Selected...") {
                viewModel.exportSelectedImages()
            }
            
            Divider()
            
            Button("Remove \(viewModel.selectedIndices.count) Selected from Album") {
                Task { await viewModel.removeSelectedImages() }
            }
        } else {
            Button("Remove from Album") {
                Task { await viewModel.removeImage(at: index) }
            }
        }
    }

    private func revealInFinder(_ image: ImageFile) {
        let url = URL(fileURLWithPath: image.path)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    // MARK: - Helpers
    
    private func tooltipText(for image: ImageFile) -> String {
        var lines = [image.path]
        let meta = viewModel.metadata[image.id]
        if let dims = meta?.dimensions {
            lines.append("\(Int(dims.width)) × \(Int(dims.height)) px")
        }
        if let size = meta?.fileSize {
            lines.append(formatFileSize(size))
        }
        return lines.joined(separator: "\n")
    }
    
    private func handleDrop(providers: [NSItemProvider]) {
        Task {
            var paths: [String] = []
            for provider in providers {
                if let path = await loadPath(from: provider) {
                    paths.append(path)
                }
            }
            if !paths.isEmpty {
                await viewModel.addImages(paths)
            }
        }
    }
    
    private func loadPath(from provider: NSItemProvider) async -> String? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    continuation.resume(returning: url.path)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private static let fileSizeFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useKB, .useMB, .useGB]
        f.countStyle = .file
        return f
    }()

    private func formatFileSize(_ bytes: Int64) -> String {
        Self.fileSizeFormatter.string(fromByteCount: bytes)
    }

    private func updateThumbnailColumnCount(width: CGFloat) {
        // cell min 120 + spacing 16; subtract 32 for grid's own padding on both sides
        let count = max(1, Int((width - 32 + 16) / (120 + 16)))
        viewModel.thumbnailColumnCount = count
    }

    private func openInPreview(_ image: ImageFile) {        guard image.exists else { return }
        NSWorkspace.shared.open(
            [URL(fileURLWithPath: image.path)],
            withAppBundleIdentifier: "com.apple.Preview",
            options: [],
            additionalEventParamDescriptor: nil,
            launchIdentifiers: nil
        )
    }
}

/// A single album list row.
///
/// This is an `Equatable` view whose identity is `(image, meta)` only — it does
/// NOT depend on selection. That way, changing the selected row does not force
/// SwiftUI to re-run this body (and its slow `ByteCountFormatter`/`DateFormatter`
/// work + tooltip build) for all ~1600 rows; the selection highlight is applied
/// by the parent via `.listRowBackground`, which is cheap.
private struct AlbumListRow: View, Equatable {
    let image: ImageFile
    let meta: ImageMetadata?
    let onClick: (_ cmd: Bool, _ shift: Bool) -> Void
    let onOpenPreview: () -> Void

    static func == (lhs: AlbumListRow, rhs: AlbumListRow) -> Bool {
        lhs.image == rhs.image && lhs.meta == rhs.meta
    }

    private static let fileSizeFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useKB, .useMB, .useGB]
        f.countStyle = .file
        return f
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        HStack {
            if meta?.exists == false {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            } else {
                Image(systemName: "photo")
                    .foregroundColor(.blue)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(image.fileName)
                    .font(.body)

                if let dimensions = meta?.dimensions, let size = meta?.fileSize {
                    Text("\(Int(dimensions.width))×\(Int(dimensions.height)) • \(Self.fileSizeFormatter.string(fromByteCount: size))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let modDate = meta?.modificationDate {
                    Text(Self.dateFormatter.string(from: modDate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onOpenPreview() }
        .onTapGesture {
            let flags = NSApp.currentEvent?.modifierFlags ?? []
            onClick(flags.contains(.command), flags.contains(.shift))
        }
        .help(tooltip)
    }

    private var tooltip: String {
        var lines = [image.path]
        if let dims = meta?.dimensions {
            lines.append("\(Int(dims.width)) × \(Int(dims.height)) px")
        }
        if let size = meta?.fileSize {
            lines.append(Self.fileSizeFormatter.string(fromByteCount: size))
        }
        return lines.joined(separator: "\n")
    }
}
