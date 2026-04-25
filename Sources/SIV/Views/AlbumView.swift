import SwiftUI

struct AlbumView: View {
    @ObservedObject var viewModel: AlbumViewModel
    @ObservedObject var imageViewModel: ImageViewModel
    
    @State private var propertiesImageFile: ImageFile?
    @State private var showBatchTimestamp = false
    
    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
        }
        .onChange(of: viewModel.selectedIndices) { _ in
            if let image = viewModel.selectedImage {
                log("🖼️ AlbumView: Selected \(image.fileName) (index \(viewModel.primarySelectedIndex ?? -1) of \(viewModel.images.count))")
                imageViewModel.loadImage(from: image)
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
        ScrollViewReader { proxy in
            List {
                ForEach(Array(viewModel.images.enumerated()), id: \.element.id) { index, image in
                    let meta = viewModel.metadata[image.id]
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
                                Text("\(Int(dimensions.width))×\(Int(dimensions.height)) • \(formatFileSize(size))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let modDate = meta?.modificationDate {
                                Text(formatDate(modDate))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .contentShape(Rectangle())
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
                    .listRowBackground(
                        viewModel.selectedIndices.contains(index)
                            ? Color.accentColor.opacity(0.2)
                            : Color.clear
                    )
                    .help(tooltipText(for: image))
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

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private func formatFileSize(_ bytes: Int64) -> String {
        Self.fileSizeFormatter.string(fromByteCount: bytes)
    }

    private func formatDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    private func openInPreview(_ image: ImageFile) {
        guard image.exists else { return }
        NSWorkspace.shared.open(
            [URL(fileURLWithPath: image.path)],
            withAppBundleIdentifier: "com.apple.Preview",
            options: [],
            additionalEventParamDescriptor: nil,
            launchIdentifiers: nil
        )
    }
}
