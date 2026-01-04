import SwiftUI
import AppKit

@main
struct SIVApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ImageViewerWindow()
        }
        .commands {
            // File menu commands
            CommandGroup(replacing: .newItem) {
                Button("Open...") {
                    openFileDialog()
                }
                .keyboardShortcut("o", modifiers: .command)
            }
            
            // View menu commands
            CommandMenu("View") {
                Button("Zoom In") {
                    NotificationCenter.default.post(name: .zoomIn, object: nil)
                }
                .keyboardShortcut("=", modifiers: .command)
                
                Button("Zoom Out") {
                    NotificationCenter.default.post(name: .zoomOut, object: nil)
                }
                .keyboardShortcut("-", modifiers: .command)
                
                Button("Actual Size") {
                    NotificationCenter.default.post(name: .actualSize, object: nil)
                }
                .keyboardShortcut("1", modifiers: .command)
                
                Button("Fit to Window") {
                    NotificationCenter.default.post(name: .fitToWindow, object: nil)
                }
                .keyboardShortcut("0", modifiers: .command)
                
                Divider()
                
                Button("Toggle Info Bar") {
                    NotificationCenter.default.post(name: .toggleInfoBar, object: nil)
                }
                .keyboardShortcut("i", modifiers: [])
                
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
    
    private func openFileDialog() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.jpeg, .png, .heic]
        panel.message = "Choose an image to open"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                NotificationCenter.default.post(
                    name: .openFile,
                    object: nil,
                    userInfo: ["url": url]
                )
            }
        }
    }
}

// Notification names for menu commands
extension Notification.Name {
    static let zoomIn = Notification.Name("zoomIn")
    static let zoomOut = Notification.Name("zoomOut")
    static let actualSize = Notification.Name("actualSize")
    static let fitToWindow = Notification.Name("fitToWindow")
    static let toggleInfoBar = Notification.Name("toggleInfoBar")
    static let nextImage = Notification.Name("nextImage")
    static let previousImage = Notification.Name("previousImage")
}

