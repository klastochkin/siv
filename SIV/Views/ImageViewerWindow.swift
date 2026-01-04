import SwiftUI

/// Main window view for the image viewer
struct ImageViewerWindow: View {
    @StateObject private var viewModel = ImageViewModel()
    
    var body: some View {
        ZStack {
            // Background
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()
            
            // Main content
            VStack(spacing: 0) {
                // Image canvas
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text(error)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.currentImage != nil {
                    ImageCanvas(viewModel: viewModel)
                } else {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "photo")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary)
                        Text("Open an image to get started")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        Text("Drag & drop or press ⌘O")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                // Info bar
                if viewModel.isInfoBarVisible && viewModel.currentFile != nil {
                    InfoBar(text: viewModel.imageInfo)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (item, error) in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else {
                return
            }
            
            Task { @MainActor in
                await viewModel.openImage(at: url)
            }
        }
        
        return true
    }
}

#Preview {
    ImageViewerWindow()
}

