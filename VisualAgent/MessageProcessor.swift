import Foundation
import Cocoa

/// Coordinates the message notification → attachment → processing → response pipeline
@MainActor
class MessageProcessor: ObservableObject {

    // MARK: - Published Properties
    @Published var isProcessing = false
    @Published var processingHistory: [ProcessedMessage] = []
    @Published var lastProcessedMessage: ProcessedMessage?

    // MARK: - Components
    private let notificationObserver = NotificationCenterObserver()
    private let attachmentWatcher = MessageAttachmentWatcher()
    private let responder = MessageResponder()
    private let settings = AppSettings.shared

    // MARK: - Configuration
    var externalProgramPath: String? {
        get { settings.externalProgramPath.isEmpty ? nil : settings.externalProgramPath }
    }
    var autoRespondEnabled: Bool {
        get { settings.autoRespondEnabled }
    }

    // MARK: - Initialization

    init() {
        print("🔄 MessageProcessor initialized")
        setupCallbacks()
    }

    // MARK: - Pipeline Control

    func start() {
        // Check if feature is enabled in settings
        guard settings.messageMonitoringEnabled else {
            print("⚠️ Message monitoring is disabled in settings")
            return
        }

        // Start notification monitoring
        notificationObserver.startMonitoring()

        // Start attachment watching
        attachmentWatcher.startWatching()

        isProcessing = true
        print("🚀 Message processing pipeline started")
    }

    func stop() {
        notificationObserver.stopMonitoring()
        attachmentWatcher.stopWatching()

        isProcessing = false
        print("⏹️ Message processing pipeline stopped")
    }

    // MARK: - Setup

    private func setupCallbacks() {
        // Notification received callback
        notificationObserver.onNotificationReceived = { [weak self] notification in
            Task { @MainActor in
                await self?.handleNotification(notification)
            }
        }

        // Attachment found callback
        attachmentWatcher.onAttachmentFound = { [weak self] fileURL, attachment in
            Task { @MainActor in
                await self?.handleAttachment(fileURL: fileURL, attachment: attachment)
            }
        }
    }

    // MARK: - Notification Handling

    private func handleNotification(_ notification: NotificationData) async {
        print("📨 Processing notification from \(notification.sender) via \(notification.displayName)")

        // If has attachment, add to pending queue
        if notification.hasAttachment {
            attachmentWatcher.addPendingAttachment(for: notification)
            print("   📎 Waiting for attachment...")
        } else {
            // No attachment - process message immediately
            await processMessage(notification: notification, attachmentURL: nil)
        }
    }

    // MARK: - Attachment Handling

    private func handleAttachment(fileURL: URL, attachment: PendingAttachment) async {
        print("📎 Processing attachment: \(fileURL.lastPathComponent)")

        // Find corresponding notification
        let notification = findNotificationForAttachment(attachment)

        // Process with attachment
        await processMessage(notification: notification, attachmentURL: fileURL)
    }

    private func findNotificationForAttachment(_ attachment: PendingAttachment) -> NotificationData {
        // Try to find in notification history
        if let found = notificationObserver.notificationHistory.first(where: {
            $0.sender == attachment.sender &&
            $0.bundleID == attachment.appBundleID &&
            abs($0.timestamp.timeIntervalSince(attachment.timestamp)) < 15 // within 15 seconds
        }) {
            return found
        }

        // Create minimal notification data
        return NotificationData(
            timestamp: attachment.timestamp,
            bundleID: attachment.appBundleID,
            appName: attachment.appBundleID == "com.apple.iChat" ? "Messages" : "WeChat",
            sender: attachment.sender,
            messageText: attachment.messageText,
            hasAttachment: true,
            attachmentHint: attachment.attachmentHint,
            notificationElement: nil
        )
    }

    // MARK: - Message Processing

    private func processMessage(notification: NotificationData, attachmentURL: URL?) async {
        print("⚙️ Processing message from \(notification.sender)")

        var processingResult: String?
        var error: String?

        // If attachment and external program configured, process it
        if let fileURL = attachmentURL, let programPath = externalProgramPath {
            processingResult = await runExternalProgram(programPath: programPath, fileURL: fileURL)
        }

        // Create processed message record
        let processed = ProcessedMessage(
            timestamp: Date(),
            notification: notification,
            attachmentURL: attachmentURL,
            processingResult: processingResult,
            error: error,
            responseSent: false
        )

        // Add to history
        processingHistory.append(processed)
        lastProcessedMessage = processed

        print("✅ Message processed")

        // Send response if enabled (iMessage only)
        if autoRespondEnabled &&
           notification.bundleID == "com.apple.iChat",
           let result = processingResult {

            await sendResponse(
                to: notification.sender,
                message: result,
                processedMessage: processed
            )
        }
    }

    // MARK: - External Program Execution

    private func runExternalProgram(programPath: String, fileURL: URL) async -> String? {
        return await withCheckedContinuation { continuation in
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: programPath)
            process.arguments = ["--file", fileURL.path]
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                try process.run()
                process.waitUntilExit()

                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outputData, encoding: .utf8) ?? ""

                if process.terminationStatus == 0 {
                    print("✅ External program completed successfully")
                    continuation.resume(returning: output.trimmingCharacters(in: .whitespacesAndNewlines))
                } else {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                    print("❌ External program failed: \(errorOutput)")
                    continuation.resume(returning: nil)
                }
            } catch {
                print("❌ Failed to run external program: \(error)")
                continuation.resume(returning: nil)
            }
        }
    }

    // MARK: - Response Sending

    private func sendResponse(to recipient: String, message: String, processedMessage: ProcessedMessage) async {
        guard processedMessage.notification.bundleID == "com.apple.iChat" else {
            print("⚠️ Cannot send response for \(processedMessage.notification.displayName) (not supported)")
            return
        }

        print("💬 Sending response to \(recipient)")

        let success = await responder.sendMessage(to: recipient, message: message)

        if success {
            print("✅ Response sent successfully")
            // Update processed message
            if let index = processingHistory.firstIndex(where: { $0.id == processedMessage.id }) {
                processingHistory[index].responseSent = true
            }
        } else {
            print("❌ Failed to send response")
        }
    }
}

// MARK: - Supporting Types

struct ProcessedMessage: Identifiable {
    let id = UUID()
    let timestamp: Date
    let notification: NotificationData
    let attachmentURL: URL?
    let processingResult: String?
    let error: String?
    var responseSent: Bool

    var displaySummary: String {
        var summary = "From: \(notification.sender) via \(notification.displayName)\n"
        summary += "Message: \(notification.messageText)\n"

        if let url = attachmentURL {
            summary += "Attachment: \(url.lastPathComponent)\n"
        }

        if let result = processingResult {
            summary += "Result: \(result.prefix(100))...\n"
        }

        if responseSent {
            summary += "✅ Response sent"
        }

        return summary
    }
}
