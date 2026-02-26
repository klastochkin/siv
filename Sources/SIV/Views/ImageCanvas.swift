import SwiftUI
import AppKit

/// Main image viewing canvas with zoom and pan support
struct ImageCanvas: View {
    @ObservedObject var viewModel: ImageViewModel
    @Binding var focusedView: ContentView.FocusedViewType
    @State private var viewSize: CGSize = .zero
    @State private var lastMagnification: CGFloat = 1.0
    @State private var dragOffset: CGSize = .zero
    @State private var propertiesImageFile: ImageFile?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                
                // Drop zone overlay - captures all drops (must be after Color.black so it's on top)
                DropZoneView { urls in
                    print("🎯 ImageCanvas: DropZoneView received \(urls.count) files")
                    if let url = urls.first {
                        let imageFile = ImageFile(path: url.path)
                        viewModel.loadImage(from: imageFile)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                
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
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in }
                        )
                        .contextMenu {
                            if let imageFile = viewModel.currentImageFile {
                                Button("Properties...") {
                                    propertiesImageFile = imageFile
                                }
                            }
                        }
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "photo")
                            .font(.system(size: 64))
                            .foregroundColor(.gray)
                        Text("No Image Loaded")
                            .font(.title2)
                            .foregroundColor(.gray)
                        Text("Press Cmd+O to open an image or drag & drop here")
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
                    .allowsHitTesting(false)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .onAppear {
                viewSize = geometry.size
                viewModel.updateViewSize(geometry.size)
                focusedView = .image
                print("📐 ImageCanvas onAppear - View size: \(geometry.size)")
            }
            .onChange(of: geometry.size) { newValue in
                viewSize = newValue
                viewModel.updateViewSize(newValue)
                print("📐 ImageCanvas size changed - View: \(newValue)")
            }
            .onChange(of: viewModel.zoomState.scale) { newScale in
                print("🔍 Zoom changed - Scale: \(newScale) (\(Int(newScale * 100))%)")
            }
            .onChange(of: viewModel.currentImage) { _ in
                if viewModel.currentImage != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        viewModel.fitToWindow()
                    }
                }
            }
            .sheet(item: $propertiesImageFile) { imageFile in
                ExifPropertiesView(imageFile: imageFile)
            }
        }
    }
}
