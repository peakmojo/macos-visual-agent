import Foundation
import CoreServices

/// Watches for message attachment files using FSEvents
@MainActor
class MessageAttachmentWatcher: ObservableObject {

    // MARK: - Published Properties
    @Published var isWatching = false
    @Published var pendingAttachments: [PendingAttachment] = []

    // MARK: - Private Properties
    private var eventStream: FSEventStreamRef?
    private let processingQueue = DispatchQueue(label: "com.visualagent.attachments", qos: .userInitiated)

    // Watched directories
    private let messagesAttachmentsPath = "\(NSHomeDirectory())/Library/Messages/Attachments"
    private let wechatBasePath = "\(NSHomeDirectory())/Library/Containers/com.tencent.xinWeChat/Data/Library/Application Support/com.tencent.xinWeChat"

    // Processing directory
    private let processingDirectory = "\(NSHomeDirectory())/Documents/VisualAgent/Processing"

    // Timeout for pending attachments (10 seconds)
    private let attachmentTimeout: TimeInterval = 10.0

    // Callback for found attachments
    var onAttachmentFound: ((URL, PendingAttachment) -> Void)?

    // MARK: - Initialization

    init() {
        print("📂 MessageAttachmentWatcher initialized")
        createProcessingDirectory()
    }

    // MARK: - Watcher Control

    func startWatching() {
        guard !isWatching else {
            print("⚠️ Already watching for attachments")
            return
        }

        setupFSEvents()
        isWatching = true
        print("👀 Started watching for attachments")
        print("   Messages: \(messagesAttachmentsPath)")
        print("   WeChat: \(wechatBasePath)")
    }

    func stopWatching() {
        guard isWatching else { return }

        if let stream = eventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            eventStream = nil
        }

        isWatching = false
        print("⏹️ Stopped watching for attachments")
    }

    // MARK: - Pending Attachment Management

    func addPendingAttachment(for notification: NotificationData) {
        guard notification.hasAttachment else { return }

        let pending = PendingAttachment(
            id: UUID(),
            timestamp: notification.timestamp,
            sender: notification.sender,
            appBundleID: notification.bundleID,
            attachmentHint: notification.attachmentHint,
            messageText: notification.messageText
        )

        pendingAttachments.append(pending)
        print("📎 Added pending attachment from \(pending.sender) (\(pending.appBundleID))")

        // Schedule timeout cleanup
        Task {
            try? await Task.sleep(nanoseconds: UInt64(attachmentTimeout * 1_000_000_000))
            await removePendingAttachment(pending)
        }
    }

    private func removePendingAttachment(_ attachment: PendingAttachment) {
        pendingAttachments.removeAll { $0.id == attachment.id }
        print("⏱️ Removed expired pending attachment from \(attachment.sender)")
    }

    // MARK: - FSEvents Setup

    private func setupFSEvents() {
        let pathsToWatch = [
            messagesAttachmentsPath as CFString,
            wechatBasePath as CFString
        ]

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        eventStream = FSEventStreamCreate(
            nil,
            fsEventsCallback,
            &context,
            pathsToWatch as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.2, // latency in seconds
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        )

        guard let stream = eventStream else {
            print("❌ Failed to create FSEventStream")
            return
        }

        FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        FSEventStreamStart(stream)

        print("✅ FSEventStream started")
    }

    // MARK: - File Processing

    nonisolated fileprivate func processFileEvent(path: String, flags: FSEventStreamEventFlags) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }

            // Only process file creation events
            guard flags & UInt32(kFSEventStreamEventFlagItemCreated) != 0 else { return }

            let fileURL = URL(fileURLWithPath: path)
            let filename = fileURL.lastPathComponent

            print("📄 File created: \(filename)")

            // Try to match with pending attachments
            if let matchedAttachment = await self.findMatchingAttachment(for: filename, at: fileURL) {
                print("✅ Matched attachment: \(filename) for \(matchedAttachment.sender)")

                // Copy to processing directory
                if let copiedURL = await self.copyToProcessingDirectory(fileURL, for: matchedAttachment) {
                    // Trigger callback
                    await self.onAttachmentFound?(copiedURL, matchedAttachment)

                    // Remove from pending
                    await self.removePendingAttachment(matchedAttachment)
                }
            }
        }
    }

    private func findMatchingAttachment(for filename: String, at fileURL: URL) -> PendingAttachment? {
        let now = Date()

        // Find attachment based on:
        // 1. Time proximity (within timeout window)
        // 2. App bundle ID (Messages vs WeChat based on path)
        // 3. Filename hint if available

        let bundleID = fileURL.path.contains("Messages") ? "com.apple.iChat" : "com.tencent.xinWeChat"

        for attachment in pendingAttachments {
            // Check app match
            guard attachment.appBundleID == bundleID else { continue }

            // Check time window
            let timeDiff = now.timeIntervalSince(attachment.timestamp)
            guard timeDiff <= attachmentTimeout else { continue }

            // If we have a filename hint, try to match it
            if let hint = attachment.attachmentHint {
                if filename.lowercased().contains(hint.lowercased()) {
                    return attachment
                }
            }

            // Otherwise, match the first pending attachment from this app within the time window
            return attachment
        }

        return nil
    }

    private func copyToProcessingDirectory(_ sourceURL: URL, for attachment: PendingAttachment) -> URL? {
        let fileManager = FileManager.default

        // Create timestamped filename
        let timestamp = Int(attachment.timestamp.timeIntervalSince1970)
        let originalName = sourceURL.lastPathComponent
        let fileExtension = sourceURL.pathExtension
        let nameWithoutExt = sourceURL.deletingPathExtension().lastPathComponent

        let newFilename = "\(attachment.appBundleID)_\(timestamp)_\(nameWithoutExt).\(fileExtension)"
        let destinationURL = URL(fileURLWithPath: processingDirectory).appendingPathComponent(newFilename)

        do {
            // Copy file
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }

            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            print("💾 Copied attachment to: \(destinationURL.path)")

            return destinationURL
        } catch {
            print("❌ Failed to copy attachment: \(error)")
            return nil
        }
    }

    private func createProcessingDirectory() {
        let fileManager = FileManager.default

        if !fileManager.fileExists(atPath: processingDirectory) {
            do {
                try fileManager.createDirectory(
                    atPath: processingDirectory,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                print("📁 Created processing directory: \(processingDirectory)")
            } catch {
                print("❌ Failed to create processing directory: \(error)")
            }
        }
    }

    // MARK: - Cleanup

    deinit {
        if let stream = eventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
        }
    }
}

// MARK: - Supporting Types

struct PendingAttachment: Identifiable {
    let id: UUID
    let timestamp: Date
    let sender: String
    let appBundleID: String
    let attachmentHint: String?
    let messageText: String
}

// MARK: - FSEvents Callback

private func fsEventsCallback(
    streamRef: ConstFSEventStreamRef,
    clientCallBackInfo: UnsafeMutableRawPointer?,
    numEvents: Int,
    eventPaths: UnsafeMutableRawPointer,
    eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    eventIds: UnsafePointer<FSEventStreamEventId>
) {
    guard let info = clientCallBackInfo else { return }

    let watcher = Unmanaged<MessageAttachmentWatcher>.fromOpaque(info).takeUnretainedValue()

    let paths = unsafeBitCast(eventPaths, to: NSArray.self) as! [String]

    for i in 0..<numEvents {
        let path = paths[i]
        let flags = eventFlags[i]

        watcher.processFileEvent(path: path, flags: flags)
    }
}
