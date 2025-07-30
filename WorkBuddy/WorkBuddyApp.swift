import SwiftUI
import AppKit

@main
struct WorkBuddyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {  
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About WorkBuddy") {
                    // About dialog could go here
                }
            }
            CommandGroup(replacing: .appTermination) {
                Button("Quit WorkBuddy") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var overlayWindow: NSWindow?
    var statusBarItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set activation policy first
        NSApp.setActivationPolicy(.accessory)
        
        // Setup status bar before overlay window
        setupStatusBar()
        setupOverlayWindow()
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
        print("Setting up status bar...")
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusBarItem?.button {
            // Try using an SF Symbol instead of emoji
            if let image = NSImage(systemSymbolName: "person.2.fill", accessibilityDescription: "WorkBuddy") {
                button.image = image
                print("Status bar button created with SF Symbol")
            } else {
                button.title = "WB"
                print("Status bar button created with text fallback: WB")
            }
        } else {
            print("Failed to create status bar button")
        }
        
        // Create status bar menu
        let menu = NSMenu()
        
        let showHideItem = NSMenuItem(title: "Show/Hide WorkBuddy", action: #selector(toggleOverlay), keyEquivalent: "")
        showHideItem.target = self
        menu.addItem(showHideItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit WorkBuddy", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusBarItem?.menu = menu
        print("Status bar menu configured")
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
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}