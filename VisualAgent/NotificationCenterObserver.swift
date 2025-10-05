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

        pollingTimer?.invalidate()
        pollingTimer = nil
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
        // First, try to read existing notifications
        readExistingNotifications()

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

        // Poll for new notifications every 5 seconds as backup
        startPolling()
    }

    private func readExistingNotifications() {
        print("🔍 Reading existing notifications from Notification Center...")

        let systemElement = AXUIElementCreateSystemWide()

        // Try to find notification center window
        var windowListRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(systemElement, kAXWindowsAttribute as CFString, &windowListRef)

        guard result == .success, let windowList = windowListRef as? [AXUIElement] else {
            print("⚠️ Could not get windows list: \(result.rawValue)")
            return
        }

        print("📋 Found \(windowList.count) windows")

        for window in windowList {
            // Get window title
            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef)
            let title = titleRef as? String ?? ""

            // Get window role
            var roleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(window, kAXRoleAttribute as CFString, &roleRef)
            let role = roleRef as? String ?? ""

            print("   Window: \(title) [\(role)]")

            // Search for notification elements
            searchForNotifications(in: window)
        }
    }

    private func searchForNotifications(in element: AXUIElement) {
        // Get all children
        var childrenRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef)

        guard result == .success, let children = childrenRef as? [AXUIElement] else {
            return
        }

        for child in children {
            // Check if this looks like a notification
            var roleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleRef)
            let role = roleRef as? String ?? ""

            var descRef: CFTypeRef?
            AXUIElementCopyAttributeValue(child, kAXDescriptionAttribute as CFString, &descRef)
            let desc = descRef as? String ?? ""

            if role.contains("Group") || role.contains("Window") || desc.contains("notification") {
                print("   🔍 Found potential notification: \(role)")
                processNotification(element: child)
            }

            // Recursively search children
            searchForNotifications(in: child)
        }
    }

    private var pollingTimer: Timer?

    private func startPolling() {
        // Poll every 5 seconds to catch notifications
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.readExistingNotifications()
            }
        }
        print("🔄 Started polling for notifications every 5 seconds")
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
            print("🔍 Processing notification element...")

            // Parse notification using NotificationParser
            guard let notificationData = await parser.parse(element: element) else {
                print("⚠️ Failed to parse notification data")
                return
            }

            print("📋 Parsed notification - App: \(notificationData.appName), BundleID: \(notificationData.bundleID)")

            // Filter for supported apps only
            guard supportedBundleIDs.contains(notificationData.bundleID) else {
                print("⏭️ Skipping notification from unsupported app: \(notificationData.bundleID)")
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
    print("🔔 AXObserver callback triggered! Notification: \(notification)")

    guard let refcon = refcon else {
        print("❌ No refcon in callback")
        return
    }

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
