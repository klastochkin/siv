import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure app settings
        NSApp.appearance = nil // Follow system appearance
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        // Handle file opening from Finder
        let url = URL(fileURLWithPath: filename)
        NotificationCenter.default.post(
            name: .openFile,
            object: nil,
            userInfo: ["url": url]
        )
        return true
    }
}

extension Notification.Name {
    static let openFile = Notification.Name("openFile")
}

