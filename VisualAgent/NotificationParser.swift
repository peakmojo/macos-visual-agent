import Foundation
import ApplicationServices
import Cocoa

/// Parses macOS notification UI elements to extract message data
class NotificationParser {

    // MARK: - Main Parsing Method

    func parse(element: AXUIElement) async -> NotificationData? {
        // Extract basic notification attributes
        guard let role = getAttribute(element, kAXRoleAttribute as CFString) as? String else {
            return nil
        }

        // Only process notification-related elements
        guard isNotificationElement(role: role, element: element) else {
            return nil
        }

        // Extract notification details
        let bundleID = getBundleIdentifier(from: element) ?? "unknown"
        let title = getAttribute(element, kAXTitleAttribute as CFString) as? String ?? ""
        let description = getAttribute(element, kAXDescriptionAttribute as CFString) as? String ?? ""
        let label = getAttribute(element, "AXLabel" as NSString as CFString) as? String ?? ""

        // Determine app name and parse sender
        let appName = getAppName(from: bundleID, title: title)
        let (sender, messageText) = parseSenderAndMessage(
            bundleID: bundleID,
            title: title,
            description: description,
            label: label
        )

        // Check for attachments
        let (hasAttachment, attachmentHint) = detectAttachment(
            bundleID: bundleID,
            text: messageText,
            description: description
        )

        print("🔍 Parsed notification:")
        print("   Bundle ID: \(bundleID)")
        print("   App: \(appName)")
        print("   Sender: \(sender)")
        print("   Message: \(messageText)")

        return NotificationData(
            timestamp: Date(),
            bundleID: bundleID,
            appName: appName,
            sender: sender,
            messageText: messageText,
            hasAttachment: hasAttachment,
            attachmentHint: attachmentHint,
            notificationElement: element
        )
    }

    // MARK: - Helper Methods

    private func getAttribute(_ element: AXUIElement, _ attribute: CFString) -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        return result == .success ? value : nil
    }

    private func isNotificationElement(role: String, element: AXUIElement) -> Bool {
        // Check for notification-specific roles
        if role.contains("Notification") || role.contains("Banner") || role.contains("Alert") {
            return true
        }

        // Check subrole for notification center elements
        if let subrole = getAttribute(element, kAXSubroleAttribute as CFString) as? String {
            if subrole.contains("Notification") || subrole == "AXNotificationCenterBanner" || subrole == "AXNotificationCenterAlert" {
                return true
            }
        }

        return false
    }

    private func getBundleIdentifier(from element: AXUIElement) -> String? {
        // Try to get bundle ID from AXIdentifier
        if let identifier = getAttribute(element, "AXIdentifier" as NSString as CFString) as? String {
            // Extract bundle ID from identifier
            if identifier.contains("com.apple.iChat") {
                return "com.apple.iChat"
            } else if identifier.contains("com.tencent.xinWeChat") {
                return "com.tencent.xinWeChat"
            }
        }

        // Try to get from StackingIdentifier (macOS specific)
        if let stackingIdentifier = getAttribute(element, "AXStackingIdentifier" as NSString as CFString) as? String {
            if stackingIdentifier.contains("com.apple.iChat") {
                return "com.apple.iChat"
            } else if stackingIdentifier.contains("com.tencent.xinWeChat") {
                return "com.tencent.xinWeChat"
            }
        }

        // Fallback: try to infer from children or parent elements
        return inferBundleIDFromContent(element: element)
    }

    private func inferBundleIDFromContent(element: AXUIElement) -> String? {
        // Get description and title to infer the app
        let title = getAttribute(element, kAXTitleAttribute as CFString) as? String ?? ""
        let description = getAttribute(element, kAXDescriptionAttribute as CFString) as? String ?? ""

        // Messages patterns
        if title.lowercased().contains("message") || description.lowercased().contains("imessage") {
            return "com.apple.iChat"
        }

        // WeChat patterns
        if title.lowercased().contains("wechat") || description.lowercased().contains("微信") {
            return "com.tencent.xinWeChat"
        }

        return nil
    }

    private func getAppName(from bundleID: String, title: String) -> String {
        switch bundleID {
        case "com.apple.iChat":
            return "Messages"
        case "com.tencent.xinWeChat":
            return "WeChat"
        default:
            return title
        }
    }

    private func parseSenderAndMessage(
        bundleID: String,
        title: String,
        description: String,
        label: String
    ) -> (sender: String, message: String) {
        switch bundleID {
        case "com.apple.iChat":
            return parseMessagesNotification(title: title, description: description, label: label)
        case "com.tencent.xinWeChat":
            return parseWeChatNotification(title: title, description: description, label: label)
        default:
            return (sender: title, message: description)
        }
    }

    private func parseMessagesNotification(title: String, description: String, label: String) -> (sender: String, message: String) {
        // iMessage format is typically:
        // Title: "Sender Name" or "iMessage"
        // Description: "Sender Name: Message text" or just "Message text"

        if description.isEmpty {
            return (sender: title, message: "")
        }

        // Check if description contains colon separator
        if let colonIndex = description.firstIndex(of: ":") {
            let sender = String(description[..<colonIndex]).trimmingCharacters(in: .whitespaces)
            let message = String(description[description.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
            return (sender: sender.isEmpty ? title : sender, message: message)
        }

        // Fallback: use title as sender, description as message
        return (sender: title, message: description)
    }

    private func parseWeChatNotification(title: String, description: String, label: String) -> (sender: String, message: String) {
        // WeChat format is typically:
        // Title: "Sender Name" or contact name
        // Description: Message text (may be truncated)

        return (sender: title.isEmpty ? "WeChat Contact" : title, message: description)
    }

    private func detectAttachment(bundleID: String, text: String, description: String) -> (hasAttachment: Bool, hint: String?) {
        // Common attachment indicators
        let attachmentKeywords = [
            "📎", "📷", "🎥", "🎤", "📄", "🖼️",
            "image", "photo", "video", "file", "document", "attachment",
            "图片", "照片", "视频", "文件"  // Chinese keywords for WeChat
        ]

        let combinedText = (text + " " + description).lowercased()

        for keyword in attachmentKeywords {
            if combinedText.contains(keyword.lowercased()) {
                return (hasAttachment: true, hint: keyword)
            }
        }

        // Check for file extensions
        let fileExtensions = ["jpg", "jpeg", "png", "gif", "pdf", "doc", "docx", "mp4", "mov", "m4a", "mp3"]
        for ext in fileExtensions {
            if combinedText.contains(".\(ext)") {
                return (hasAttachment: true, hint: ".\(ext)")
            }
        }

        return (hasAttachment: false, hint: nil)
    }
}
