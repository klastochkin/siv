import SwiftUI

@main
struct SIVApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 600, minHeight: 400)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            SIVCommands()
        }
    }
}

/// Application commands (menu items)
struct SIVCommands: Commands {
    var body: some Commands {
        // File menu
        CommandGroup(replacing: .newItem) {
            Button("Open Image...") {
                NotificationCenter.default.post(name: .openImage, object: nil)
            }
            .keyboardShortcut("o", modifiers: .command)
            
            Divider()
            
            Button("Add to Album...") {
                NotificationCenter.default.post(name: .addImagesToAlbum, object: nil)
            }

            Divider()

            Button("Upload from Memory Card...") {
                NotificationCenter.default.post(name: .uploadFromMemCard, object: nil)
            }
        }
        
        // View menu
        CommandMenu("View") {
            Button("Toggle Album/Image View") {
                NotificationCenter.default.post(name: .toggleAlbumView, object: nil)
            }
            .keyboardShortcut("t", modifiers: .command)
            
            Divider()
            
            Button("Thumbnails") {
                NotificationCenter.default.post(name: .setThumbnailView, object: nil)
            }
            
            Button("List") {
                NotificationCenter.default.post(name: .setListView, object: nil)
            }
        }
        
        // Image menu
        CommandMenu("Image") {
            Button("Fit to Window") {
                NotificationCenter.default.post(name: .fitToWindow, object: nil)
            }
            .keyboardShortcut("0", modifiers: .command)
            
            Button("Actual Size") {
                NotificationCenter.default.post(name: .actualSize, object: nil)
            }
            .keyboardShortcut("1", modifiers: .command)
            
            Divider()
            
            Button("Zoom In") {
                NotificationCenter.default.post(name: .zoomIn, object: nil)
            }
            .keyboardShortcut("+", modifiers: .command)
            
            Button("Zoom Out") {
                NotificationCenter.default.post(name: .zoomOut, object: nil)
            }
            .keyboardShortcut("-", modifiers: .command)
        }
        
        // Album menu
        CommandMenu("Album") {
            Button("Add Images...") {
                NotificationCenter.default.post(name: .addImagesToAlbum, object: nil)
            }

            Button("Upload from Memory Card...") {
                NotificationCenter.default.post(name: .uploadFromMemCard, object: nil)
            }

            Button("Export Selected...") {
                NotificationCenter.default.post(name: .exportSelectedImages, object: nil)
            }
            .keyboardShortcut("e", modifiers: .command)
            
            Divider()
            
            Button("Next Image") {
                NotificationCenter.default.post(name: .nextImage, object: nil)
            }
            .keyboardShortcut(.rightArrow, modifiers: [])
            
            Button("Previous Image") {
                NotificationCenter.default.post(name: .previousImage, object: nil)
            }
            .keyboardShortcut(.leftArrow, modifiers: [])
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let openImage = Notification.Name("openImage")
    static let addToAlbum = Notification.Name("addToAlbum")
    static let addImagesToAlbum = Notification.Name("addImagesToAlbum")
    static let toggleAlbumView = Notification.Name("toggleAlbumView")
    static let setThumbnailView = Notification.Name("setThumbnailView")
    static let setListView = Notification.Name("setListView")
    static let fitToWindow = Notification.Name("fitToWindow")
    static let actualSize = Notification.Name("actualSize")
    static let zoomIn = Notification.Name("zoomIn")
    static let zoomOut = Notification.Name("zoomOut")
    static let nextImage = Notification.Name("nextImage")
    static let previousImage = Notification.Name("previousImage")
    static let exportSelectedImages = Notification.Name("exportSelectedImages")
    static let uploadFromMemCard = Notification.Name("uploadFromMemCard")
}
