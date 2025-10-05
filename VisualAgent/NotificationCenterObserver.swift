import Foundation
import ApplicationServices
import Cocoa

/// Observes macOS Notification Center for Messages and WeChat notifications using Accessibility APIs
@MainActor
class NotificationCenterObserver: ObservableObject {

    // MARK: - Published Properties
    @Published var isMonitoring = false
    @Published var lastNotification: NotificationData?
    @Published var notificationHistory: [NotificationData] = []

    // MARK: - Private Properties
    private var observer: AXObserver?
    private let parser = NotificationParser()
    private var runLoopSource: CFRunLoopSource?

    // Supported apps
    private let supportedBundleIDs = [
        "com.apple.iChat",          // Messages
        "com.tencent.xinWeChat"     // WeChat
    ]

    // Callback for notifications
    var onNotificationReceived: ((NotificationData) -> Void)?

    // MARK: - Initialization

    init() {
        print("📱 NotificationCenterObserver initialized")
    }

    // MARK: - Observer Control

    func startMonitoring() {
        guard !isMonitoring else {
            print("⚠️ Already monitoring notifications")
            return
        }

        // Check Accessibility permissions
        guard checkAccessibilityPermission() else {
            print("❌ Accessibility permission required for notification monitoring")
            requestAccessibilityPermission()
            return
        }

        setupObserver()
        isMonitoring = true
        print("🚀 Started notification monitoring for Messages & WeChat")
    }

    func stopMonitoring() {
        guard isMonitoring else { return }

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .defaultMode)
        }

        observer = nil
        runLoopSource = nil
        isMonitoring = false
        print("⏹️ Stopped notification monitoring")
    }

    // MARK: - Accessibility Permissions

    private func checkAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }

    private func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Observer Setup

    private func setupObserver() {
        // Get Notification Center UI process
        guard let notificationCenterPID = getNotificationCenterPID() else {
            print("❌ Could not find Notification Center process")
            return
        }

        print("📍 Found Notification Center PID: \(notificationCenterPID)")

        // Create observer
        var obs: AXObserver?
        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        let result = AXObserverCreate(notificationCenterPID, axObserverCallback, &obs)

        guard result == .success, let observer = obs else {
            print("❌ Failed to create AXObserver: \(result.rawValue)")
            return
        }

        self.observer = observer

        // Get system-wide element to monitor all notifications
        let systemElement = AXUIElementCreateSystemWide()

        // Add notification for created elements (new notification banners)
        let addNotificationResult = AXObserverAddNotification(
            observer,
            systemElement,
            kAXCreatedNotification as CFString,
            selfPtr
        )

        if addNotificationResult == .success {
            print("✅ Successfully added AXCreatedNotification observer")
        } else {
            print("⚠️ Failed to add notification observer: \(addNotificationResult.rawValue)")
        }

        // Add to run loop
        runLoopSource = AXObserverGetRunLoopSource(observer)
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .defaultMode)
            print("✅ Added observer to run loop")
        }
    }

    // MARK: - Helper Functions

    private func getNotificationCenterPID() -> pid_t? {
        // Try to find NotificationCenter process
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications

        // NotificationCenter runs as part of the system UI
        for app in runningApps {
            if app.bundleIdentifier == "com.apple.notificationcenterui" {
                return app.processIdentifier
            }
        }

        // Alternative: Use system-wide element
        // This allows monitoring notifications without specific PID
        return nil
    }

    // MARK: - Notification Processing

    fileprivate func processNotification(element: AXUIElement) {
        Task { @MainActor in
            // Parse notification using NotificationParser
            guard let notificationData = await parser.parse(element: element) else {
                return
            }

            // Filter for supported apps only
            guard supportedBundleIDs.contains(notificationData.bundleID) else {
                return
            }

            print("📬 Received notification from: \(notificationData.appName)")
            print("   Sender: \(notificationData.sender)")
            print("   Message: \(notificationData.messageText)")
            if notificationData.hasAttachment {
                print("   📎 Has attachment: \(notificationData.attachmentHint ?? "unknown")")
            }

            // Update state
            lastNotification = notificationData
            notificationHistory.append(notificationData)

            // Trigger callback
            onNotificationReceived?(notificationData)
        }
    }
}

// MARK: - C Callback Function

private func axObserverCallback(
    observer: AXObserver,
    element: AXUIElement,
    notification: CFString,
    refcon: UnsafeMutableRawPointer?
) {
    guard let refcon = refcon else { return }

    let observerInstance = Unmanaged<NotificationCenterObserver>.fromOpaque(refcon).takeUnretainedValue()

    // Process on main actor
    Task { @MainActor in
        observerInstance.processNotification(element: element)
    }
}

// MARK: - Supporting Types

struct NotificationData: Identifiable {
    let id = UUID()
    let timestamp: Date
    let bundleID: String
    let appName: String
    let sender: String
    let messageText: String
    let hasAttachment: Bool
    let attachmentHint: String?
    let notificationElement: AXUIElement?

    var displayName: String {
        switch bundleID {
        case "com.apple.iChat":
            return "iMessage"
        case "com.tencent.xinWeChat":
            return "WeChat"
        default:
            return appName
        }
    }
}
