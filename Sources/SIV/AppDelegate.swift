import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Activate the app and bring window to front
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        // Set minimum window size and bring to front
        if let window = NSApplication.shared.windows.first {
            window.minSize = NSSize(width: 600, height: 400)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func applicationWillBecomeActive(_ notification: Notification) {
        // Ensure window is key when app becomes active
        if let window = NSApplication.shared.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
