import SwiftUI
import AppKit

@main
struct VisualAgentApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {  
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Visual Agent") {
                    // About dialog could go here
                }
            }
            CommandGroup(replacing: .appTermination) {
                Button("Quit Visual Agent") {
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

        // Start with minimal size for just the mini bar
        overlayWindow = CustomWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 50),
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
        overlayWindow?.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]
        overlayWindow?.isMovableByWindowBackground = false
        
        // Add rounded corners to the window
        overlayWindow?.contentView?.wantsLayer = true
        overlayWindow?.contentView?.layer?.cornerRadius = 16
        overlayWindow?.contentView?.layer?.masksToBounds = true
        
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
        // Use variable length to accommodate the custom view
        statusBarItem = NSStatusBar.system.statusItem(withLength: 300)
        
        if let button = statusBarItem?.button {
            // Create custom status bar view
            let statusBarView = StatusBarView()
            let hostingView = NSHostingView(rootView: statusBarView)
            hostingView.frame = NSRect(x: 0, y: 0, width: 300, height: 44)
            
            // Remove the default button appearance
            button.image = nil
            button.title = ""
            button.wantsLayer = true
            button.layer?.backgroundColor = NSColor.clear.cgColor
            
            // Add the SwiftUI view as a subview
            button.addSubview(hostingView)
            hostingView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                hostingView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
                hostingView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
                hostingView.widthAnchor.constraint(equalToConstant: 300),
                hostingView.heightAnchor.constraint(equalToConstant: 44)
            ])
            
            print("Custom status bar view created")
        } else {
            print("Failed to create status bar button")
        }
        
        // Create status bar menu (for right-click)
        let menu = NSMenu()
        
        let showHideItem = NSMenuItem(title: "Show/Hide Visual Agent", action: #selector(toggleOverlay), keyEquivalent: "")
        showHideItem.target = self
        menu.addItem(showHideItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit Visual Agent", action: #selector(quitApp), keyEquivalent: "q")
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
    
    func updateWindowSize(isExpanded: Bool, showTaskTimeline: Bool) {
        guard let window = overlayWindow else { 
            print("Warning: overlayWindow is nil")
            return 
        }
        
        let newSize: NSSize
        if showTaskTimeline {
            // When task timeline is shown, window takes more space
            newSize = isExpanded ? NSSize(width: 780, height: 500) : NSSize(width: 700, height: 80)
        } else {
            // When task timeline is hidden, smaller footprint
            newSize = isExpanded ? NSSize(width: 400, height: 500) : NSSize(width: 360, height: 80)
        }
        
        print("Updating window size to: \(newSize), isExpanded: \(isExpanded), showTaskTimeline: \(showTaskTimeline)")
        
        // Get current frame and preserve position
        let currentFrame = window.frame
        let newFrame = NSRect(
            x: currentFrame.origin.x,
            y: currentFrame.origin.y - (newSize.height - currentFrame.size.height), // Adjust y to keep top-right anchor
            width: newSize.width,
            height: newSize.height
        )
        
        // Ensure window stays visible
        window.setFrame(newFrame, display: true, animate: true)
        window.makeKeyAndOrderFront(nil)
    }
}

class CustomWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return true
    }
}