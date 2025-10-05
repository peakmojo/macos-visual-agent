import Foundation
import Cocoa

/// Sends iMessage responses using AppleScript via NSUserAppleScriptTask
@MainActor
class MessageResponder {

    // MARK: - Properties
    private let scriptName = "sendMessage.scpt"
    private var scriptURL: URL?

    // MARK: - Initialization

    init() {
        scriptURL = getScriptURL()
        if scriptURL == nil {
            print("⚠️ AppleScript not found. Response sending disabled.")
            print("   Expected location: ~/Library/Application Scripts/\(Bundle.main.bundleIdentifier ?? "unknown")/\(scriptName)")
        } else {
            print("✅ Found AppleScript at: \(scriptURL!.path)")
        }
    }

    // MARK: - Send Message

    func sendMessage(to recipient: String, message: String) async -> Bool {
        guard let scriptURL = scriptURL else {
            print("❌ Cannot send message: AppleScript not available")
            return false
        }

        return await withCheckedContinuation { continuation in
            do {
                // Create NSUserAppleScriptTask
                let task = try NSUserAppleScriptTask(url: scriptURL)

                // Execute with nil event - the script will use the run handler with args
                task.execute(withAppleEvent: nil) { result, error in
                    if let error = error {
                        print("❌ AppleScript execution failed: \(error.localizedDescription)")
                        continuation.resume(returning: false)
                    } else {
                        print("✅ Message sent successfully to \(recipient)")
                        continuation.resume(returning: true)
                    }
                }
            } catch {
                print("❌ Failed to create AppleScript task: \(error.localizedDescription)")
                continuation.resume(returning: false)
            }
        }
    }

    // MARK: - Helper Methods

    private func getScriptURL() -> URL? {
        // Get Application Scripts directory
        guard let bundleID = Bundle.main.bundleIdentifier else {
            print("❌ Cannot determine bundle identifier")
            return nil
        }

        let fileManager = FileManager.default

        // Try to find the script in Application Scripts directory
        let applicationScriptsURL = fileManager.urls(
            for: .applicationScriptsDirectory,
            in: .userDomainMask
        ).first

        guard let scriptsDir = applicationScriptsURL else {
            print("❌ Cannot find Application Scripts directory")
            return nil
        }

        let scriptURL = scriptsDir.appendingPathComponent(scriptName)

        // Check if script exists
        if fileManager.fileExists(atPath: scriptURL.path) {
            return scriptURL
        }

        // Try creating the directory if it doesn't exist
        if !fileManager.fileExists(atPath: scriptsDir.path) {
            do {
                try fileManager.createDirectory(at: scriptsDir, withIntermediateDirectories: true)
                print("📁 Created Application Scripts directory: \(scriptsDir.path)")
            } catch {
                print("❌ Failed to create Application Scripts directory: \(error)")
                return nil
            }
        }

        // Script doesn't exist, provide instructions
        print("ℹ️  To enable message sending, create \(scriptName) at:")
        print("   \(scriptsDir.path)")
        print("")
        print("   Script content:")
        print("   ---------------")
        print(getScriptTemplate())
        print("   ---------------")

        return nil
    }

    private func getScriptTemplate() -> String {
        return """
        on run {targetBuddy, messageText}
            tell application "Messages"
                set targetService to 1st service whose service type = iMessage
                set theBuddy to buddy targetBuddy of targetService
                send messageText to theBuddy
            end tell
        end run
        """
    }

    // MARK: - Setup Helper

    func createScriptIfNeeded() -> Bool {
        guard scriptURL == nil else {
            return true // Already exists
        }

        guard let bundleID = Bundle.main.bundleIdentifier else {
            return false
        }

        let fileManager = FileManager.default

        let applicationScriptsURL = fileManager.urls(
            for: .applicationScriptsDirectory,
            in: .userDomainMask
        ).first

        guard let scriptsDir = applicationScriptsURL else {
            return false
        }

        // Create directory if needed
        if !fileManager.fileExists(atPath: scriptsDir.path) {
            do {
                try fileManager.createDirectory(at: scriptsDir, withIntermediateDirectories: true)
            } catch {
                print("❌ Failed to create scripts directory: \(error)")
                return false
            }
        }

        // Write script
        let scriptURL = scriptsDir.appendingPathComponent(scriptName)
        let scriptContent = getScriptTemplate()

        do {
            try scriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)
            print("✅ Created AppleScript at: \(scriptURL.path)")
            self.scriptURL = scriptURL
            return true
        } catch {
            print("❌ Failed to write AppleScript: \(error)")
            return false
        }
    }

    func getScriptLocation() -> String? {
        return scriptURL?.path
    }
}
