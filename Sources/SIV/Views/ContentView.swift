import SwiftUI

/// Main content view with split Image and Album views
struct ContentView: View {
    @StateObject private var imageViewModel = ImageViewModel()
    @StateObject private var albumViewModel = AlbumViewModel()
    @StateObject private var toastManager = ToastManager()
    @StateObject private var memCardImport = MemCardImportViewModel()

    @State private var showAlbumView = true
    @State private var focusedView: FocusedViewType = .image
    @State private var showMemCardImport = false
    
    enum FocusedViewType {
        case image
        case album
    }
    
    var body: some View {
        ZStack {
            HSplitView {
                if showAlbumView {
                    AlbumView(
                        viewModel: albumViewModel,
                        imageViewModel: imageViewModel,
                        memCardImport: memCardImport,
                        showMemCardImport: $showMemCardImport
                    )
                        .frame(minWidth: 200)
                        .background(Color(NSColor.windowBackgroundColor))
                        .border(focusedView == .album ? Color.accentColor : Color.clear, width: 2)
                        .simultaneousGesture(TapGesture().onEnded {
                            focusedView = .album
                        })
                }
                
                ImageCanvas(viewModel: imageViewModel, focusedView: $focusedView)
                    .frame(minWidth: 400)
                    .border(focusedView == .image ? Color.accentColor : Color.clear, width: 2)
                    .onTapGesture {
                        focusedView = .image
                    }
            }
            
            // Invisible buttons for keyboard shortcuts
            KeyboardShortcutHandler(
                imageViewModel: imageViewModel,
                albumViewModel: albumViewModel,
                toastManager: toastManager,
                focusedView: $focusedView,
                showAlbumView: $showAlbumView
            )

            ToastOverlayView(manager: toastManager)
        }
        .task {
            await albumViewModel.initialize()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openImage)) { _ in
            imageViewModel.openImageFile()
        }
        .onReceive(NotificationCenter.default.publisher(for: .addToAlbum)) { _ in
            // Cmd+A: Add current image to album
            log("🔔 ContentView: Received .addToAlbum notification")
            if let imageFile = imageViewModel.currentImageFile {
                log("📸 ContentView: Adding current image to album: \(imageFile.path)")
                Task { await albumViewModel.addImage(imageFile.path) }
            } else {
                log("⚠️ ContentView: No current image to add")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .addImagesToAlbum)) { _ in
            // Menu: Open file picker to add multiple images
            log("🔔 ContentView: Received .addImagesToAlbum notification")
            albumViewModel.openFilePicker()
        }
        .onReceive(NotificationCenter.default.publisher(for: .fitToWindow)) { _ in
            imageViewModel.fitToWindow()
        }
        .onReceive(NotificationCenter.default.publisher(for: .actualSize)) { _ in
            imageViewModel.actualSize()
        }
        .onReceive(NotificationCenter.default.publisher(for: .zoomIn)) { _ in
            imageViewModel.zoomIn()
        }
        .onReceive(NotificationCenter.default.publisher(for: .zoomOut)) { _ in
            imageViewModel.zoomOut()
        }
        .onReceive(NotificationCenter.default.publisher(for: .nextImage)) { _ in
            if focusedView == .album {
                albumViewModel.selectNextImage()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .previousImage)) { _ in
            if focusedView == .album {
                albumViewModel.selectPreviousImage()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .exportSelectedImages)) { _ in
            albumViewModel.exportSelectedImages()
        }
        .onReceive(NotificationCenter.default.publisher(for: .uploadFromMemCard)) { _ in
            memCardImport.begin(album: albumViewModel)
            showMemCardImport = true
        }
        .sheet(isPresented: $showMemCardImport) {
            MemCardImportView(vm: memCardImport)
        }
    }
}

/// Invisible view that handles keyboard shortcuts
struct KeyboardShortcutHandler: View {
    @ObservedObject var imageViewModel: ImageViewModel
    @ObservedObject var albumViewModel: AlbumViewModel
    @ObservedObject var toastManager: ToastManager
    @Binding var focusedView: ContentView.FocusedViewType
    @Binding var showAlbumView: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Cmd+O - Open
            Button("") { imageViewModel.openImageFile() }
                .keyboardShortcut("o", modifiers: .command)
                .opacity(0)
                .frame(width: 0, height: 0)
            
            // Cmd+A - Add to album
            Button("") {
                if let imageFile = imageViewModel.currentImageFile {
                    Task { await albumViewModel.addImage(imageFile.path) }
                }
            }
            .keyboardShortcut("a", modifiers: .command)
            .opacity(0)
            .frame(width: 0, height: 0)
            
            // Cmd+0 - Fit to window
            Button("") { imageViewModel.fitToWindow() }
                .keyboardShortcut("0", modifiers: .command)
                .opacity(0)
                .frame(width: 0, height: 0)
            
            // Cmd+1 - Actual size
            Button("") { imageViewModel.actualSize() }
                .keyboardShortcut("1", modifiers: .command)
                .opacity(0)
                .frame(width: 0, height: 0)
            
            // Cmd++ - Zoom in
            Button("") { imageViewModel.zoomIn() }
                .keyboardShortcut("+", modifiers: .command)
                .opacity(0)
                .frame(width: 0, height: 0)
            
            // Cmd+- - Zoom out
            Button("") { imageViewModel.zoomOut() }
                .keyboardShortcut("-", modifiers: .command)
                .opacity(0)
                .frame(width: 0, height: 0)
            
            // Arrow keys
            Button("") {
                if focusedView == .image {
                    imageViewModel.panLeft()
                } else {
                    albumViewModel.selectPreviousImage()
                }
            }
            .keyboardShortcut(.leftArrow, modifiers: [])
            .opacity(0)
            .frame(width: 0, height: 0)
            
            Button("") {
                if focusedView == .image {
                    imageViewModel.panRight()
                } else {
                    albumViewModel.selectNextImage()
                }
            }
            .keyboardShortcut(.rightArrow, modifiers: [])
            .opacity(0)
            .frame(width: 0, height: 0)
            
            Button("") {
                if focusedView == .image {
                    imageViewModel.panUp()
                } else if albumViewModel.viewMode == .thumbnails {
                    albumViewModel.selectImageUp()
                } else {
                    albumViewModel.selectPreviousImage()
                }
            }
            .keyboardShortcut(.upArrow, modifiers: [])
            .opacity(0)
            .frame(width: 0, height: 0)
            
            Button("") {
                if focusedView == .image {
                    imageViewModel.panDown()
                } else if albumViewModel.viewMode == .thumbnails {
                    albumViewModel.selectImageDown()
                } else {
                    albumViewModel.selectNextImage()
                }
            }
            .keyboardShortcut(.downArrow, modifiers: [])
            .opacity(0)
            .frame(width: 0, height: 0)
            
            // Space - next image in album
            Button("") {
                if focusedView == .album {
                    albumViewModel.selectNextImage()
                }
            }
            .keyboardShortcut(.space, modifiers: [])
            .opacity(0)
            .frame(width: 0, height: 0)
            
            // Tab - switch focus
            Button("") {
                focusedView = focusedView == .image ? .album : .image
            }
            .keyboardShortcut(.tab, modifiers: [])
            .opacity(0)
            .frame(width: 0, height: 0)

            // Delete - move selected file to Trash
            Button("") {
                guard focusedView == .album else { return }
                Task {
                    if let record = await albumViewModel.deleteSelectedFile() {
                        toastManager.show("'\(record.fileName)' moved to Trash  —  ⌘Z to restore")
                    }
                }
            }
            .keyboardShortcut(.delete, modifiers: [])
            .opacity(0)
            .frame(width: 0, height: 0)

            // Cmd+Z - undo last deletion
            Button("") {
                Task {
                    if let fileName = await albumViewModel.undoLastDelete() {
                        toastManager.show("'\(fileName)' restored")
                    }
                }
            }
            .keyboardShortcut("z", modifiers: .command)
            .opacity(0)
            .frame(width: 0, height: 0)
        }
        .frame(width: 0, height: 0)
    }
}
