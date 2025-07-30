import SwiftUI
import AppKit

@main
struct WorkBuddyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var overlayWindow: NSWindow?
    var statusBarItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupOverlayWindow()
        setupStatusBar()
        NSApp.setActivationPolicy(.accessory)
    }
    
    private func setupOverlayWindow() {
        let contentView = ContentView()
        
        overlayWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 400),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        overlayWindow?.contentView = NSHostingView(rootView: contentView)
        overlayWindow?.backgroundColor = NSColor.clear
        overlayWindow?.isOpaque = false
        overlayWindow?.level = NSWindow.Level.floating
        overlayWindow?.ignoresMouseEvents = false
        overlayWindow?.acceptsMouseMovedEvents = true
        overlayWindow?.collectionBehavior = [.canJoinAllSpaces]
        overlayWindow?.isMovableByWindowBackground = true
        
        // Position window in top-right corner
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let windowRect = overlayWindow!.frame
            let x = screenRect.maxX - windowRect.width - 20
            let y = screenRect.maxY - windowRect.height - 20
            overlayWindow?.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        overlayWindow?.makeKeyAndOrderFront(nil)
    }
    
    private func setupStatusBar() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusBarItem?.button?.title = "👥"
        statusBarItem?.button?.action = #selector(toggleOverlay)
        statusBarItem?.button?.target = self
    }
    
    @objc private func toggleOverlay() {
        if let window = overlayWindow {
            if window.isVisible {
                window.orderOut(nil)
            } else {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }
}