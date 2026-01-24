import SwiftUI
import AppKit

/// Main image viewing canvas with zoom and pan support
struct ImageCanvas: View {
    @ObservedObject var viewModel: ImageViewModel
    @Binding var focusedView: ContentView.FocusedViewType
    @State private var viewSize: CGSize = .zero
    @State private var lastMagnification: CGFloat = 1.0
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                } else if let image = viewModel.currentImage {
                    let displayWidth = max(1, viewModel.zoomState.imageSize.width * viewModel.zoomState.scale)
                    let displayHeight = max(1, viewModel.zoomState.imageSize.height * viewModel.zoomState.scale)
                    let imageAspectRatio = viewModel.zoomState.imageSize.height > 0
                        ? viewModel.zoomState.imageSize.width / viewModel.zoomState.imageSize.height
                        : 1.0
                    
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(imageAspectRatio, contentMode: .fill)
                        .frame(width: displayWidth, height: displayHeight)
                        .offset(viewModel.zoomState.offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastMagnification
                                    viewModel.zoomState.applyPinchZoom(magnification: delta)
                                    lastMagnification = value
                                }
                                .onEnded { _ in
                                    lastMagnification = 1.0
                                }
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let delta = CGSize(
                                        width: value.translation.width - dragOffset.width,
                                        height: value.translation.height - dragOffset.height
                                    )
                                    viewModel.zoomState.pan(by: delta)
                                    dragOffset = value.translation
                                }
                                .onEnded { _ in
                                    dragOffset = .zero
                                }
                        )
                        .simultaneousGesture(
                            // Enable scroll wheel zoom
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in }
                        )
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "photo")
                            .font(.system(size: 64))
                            .foregroundColor(.gray)
                        Text("No Image Loaded")
                            .font(.title2)
                            .foregroundColor(.gray)
                        Text("Press Cmd+O to open an image")
                            .font(.body)
                            .foregroundColor(.gray.opacity(0.7))
                    }
                }
                
                // Info bar - explicitly anchored to view bottom (not image)
                if viewModel.currentImage != nil {
                    VStack(spacing: 0) {
                        Spacer()
                        HStack {
                            Spacer()
                            InfoBar(info: viewModel.imageInfo)
                            Spacer()
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .allowsHitTesting(true)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .onAppear {
                viewSize = geometry.size
                viewModel.updateViewSize(geometry.size)
                focusedView = .image
                print("📐 ImageCanvas onAppear - View size: \(geometry.size)")
            }
            .onChange(of: geometry.size) { newValue in
                viewSize = newValue
                viewModel.updateViewSize(newValue)
                print("📐 ImageCanvas size changed - View: \(newValue), Image: \(viewModel.zoomState.imageSize), Display: \(viewModel.zoomState.displaySize), Scale: \(viewModel.zoomState.scale)")
            }
            .onChange(of: viewModel.zoomState.scale) { newScale in
                let displaySize = viewModel.zoomState.displaySize
                print("🔍 Zoom changed - Scale: \(newScale) (\(Int(newScale * 100))%), Display: \(displaySize), Offset: \(viewModel.zoomState.offset)")
                print("📍 View bounds: \(geometry.size), InfoBar should be at bottom: y=\(geometry.size.height - 50)")
            }
            .onChange(of: viewModel.currentImage) { _ in
                // Ensure image is properly sized when loaded
                if viewModel.currentImage != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        viewModel.fitToWindow()
                    }
                }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
            return true
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }
        
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else {
                return
            }
            
            DispatchQueue.main.async {
                let imageFile = ImageFile(path: url.path)
                viewModel.loadImage(from: imageFile)
            }
        }
    }
}
