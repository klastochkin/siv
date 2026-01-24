import SwiftUI

/// Album view displaying list or thumbnails of images
struct AlbumView: View {
    @ObservedObject var viewModel: AlbumViewModel
    @ObservedObject var imageViewModel: ImageViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Album")
                    .font(.headline)
                
                Spacer()
                
                Picker("View Mode", selection: $viewModel.viewMode) {
                    ForEach(AlbumViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
                
                Button(action: {
                    viewModel.openFilePicker()
                }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Content
            if viewModel.images.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("No Images in Album")
                        .font(.title3)
                        .foregroundColor(.gray)
                    Text("Drag & drop images or use the + button")
                        .font(.body)
                        .foregroundColor(.gray.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                if viewModel.viewMode == .list {
                    listView
                } else {
                    thumbnailView
                }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
            return true
        }
        .alert("Missing Files", isPresented: $viewModel.showMissingFilesDialog) {
            Button("Remove All Missing Files") {
                Task {
                    await viewModel.removeMissingFiles()
                }
            }
            Button("Cancel", role: .cancel) {
                viewModel.showMissingFilesDialog = false
            }
        } message: {
            Text("The following files are missing:\n\n" + 
                 viewModel.missingFiles.map { $0.fileName }.joined(separator: "\n"))
        }
    }
    
    private var listView: some View {
        List(selection: $viewModel.selectedImageIndex) {
            ForEach(Array(viewModel.images.enumerated()), id: \.element.id) { index, image in
                HStack {
                    if !image.exists {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    } else {
                        Image(systemName: "photo")
                            .foregroundColor(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(image.fileName)
                            .font(.body)
                        
                        if let dimensions = image.dimensions, let size = image.fileSize {
                            Text("\(Int(dimensions.width))×\(Int(dimensions.height)) • \(formatFileSize(size))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                .tag(index)
                .contextMenu {
                    Button("Remove from Album") {
                        Task {
                            await viewModel.removeImage(at: index)
                        }
                    }
                }
            }
        }
        .onChange(of: viewModel.selectedImageIndex) { newValue in
            if let index = newValue, index < viewModel.images.count {
                let imageFile = viewModel.images[index]
                imageViewModel.loadImage(from: imageFile)
            }
        }
    }
    
    private var thumbnailView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 16) {
                ForEach(Array(viewModel.images.enumerated()), id: \.element.id) { index, image in
                    VStack {
                        ZStack {
                            if let nsImage = image.loadImage() {
                                Image(nsImage: nsImage)
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
                            
                            if !image.exists {
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
                    .background(viewModel.selectedImageIndex == index ? Color.accentColor.opacity(0.2) : Color.clear)
                    .cornerRadius(8)
                    .onTapGesture {
                        viewModel.selectImage(at: index)
                        let imageFile = viewModel.images[index]
                        imageViewModel.loadImage(from: imageFile)
                    }
                    .contextMenu {
                        Button("Remove from Album") {
                            Task {
                                await viewModel.removeImage(at: index)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) {
        print("DEBUG: handleDrop called with \(providers.count) providers")
        Task {
            var paths: [String] = []
            
            for provider in providers {
                if let path = await loadPath(from: provider) {
                    print("DEBUG: Loaded path: \(path)")
                    paths.append(path)
                }
            }
            
            print("DEBUG: Total paths: \(paths.count)")
            if !paths.isEmpty {
                await viewModel.addImages(paths)
                print("DEBUG: Images added to album")
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
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
