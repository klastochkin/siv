import SwiftUI
import AppKit

/// A view that reliably accepts file drops using NSView
struct DropZoneView: NSViewRepresentable {
    let onDrop: ([URL]) -> Void
    
    func makeNSView(context: Context) -> DropReceivingView {
        let view = DropReceivingView()
        view.onDrop = onDrop
        return view
    }
    
    func updateNSView(_ nsView: DropReceivingView, context: Context) {
        nsView.onDrop = onDrop
    }
}

class DropReceivingView: NSView {
    var onDrop: (([URL]) -> Void)?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupDragAndDrop()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupDragAndDrop()
    }
    
    private func setupDragAndDrop() {
        registerForDraggedTypes([.fileURL])
        print("✨ DropReceivingView: Registered for file URL drops")
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        print("👋 DropReceivingView: Drag entered")
        
        guard let items = sender.draggingPasteboard.pasteboardItems else {
            print("❌ DropReceivingView: No pasteboard items")
            return []
        }
        
        // Check if any item is a file URL
        for item in items {
            if let urlString = item.string(forType: .fileURL),
               let url = URL(string: urlString),
               url.isFileURL {
                let ext = url.pathExtension.lowercased()
                if ["jpg", "jpeg", "png", "heic", "heif"].contains(ext) {
                    print("✅ DropReceivingView: Valid image file detected: \(url.lastPathComponent)")
                    return .copy
                }
            }
        }
        
        print("⚠️ DropReceivingView: No valid image files")
        return []
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        print("🎯 DropReceivingView: performDragOperation called")
        
        guard let items = sender.draggingPasteboard.pasteboardItems else {
            print("❌ DropReceivingView: No pasteboard items")
            return false
        }
        
        var urls: [URL] = []
        
        for item in items {
            if let urlString = item.string(forType: .fileURL),
               let url = URL(string: urlString),
               url.isFileURL {
                let ext = url.pathExtension.lowercased()
                if ["jpg", "jpeg", "png", "heic", "heif"].contains(ext) {
                    urls.append(url)
                    print("📁 DropReceivingView: Added URL: \(url.path)")
                }
            }
        }
        
        if !urls.isEmpty {
            print("✅ DropReceivingView: Calling onDrop with \(urls.count) files")
            onDrop?(urls)
            return true
        }
        
        print("❌ DropReceivingView: No valid URLs to drop")
        return false
    }
}
