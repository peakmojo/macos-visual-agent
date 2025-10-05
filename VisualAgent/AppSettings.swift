import Foundation
import SwiftUI

/// Application settings with persistent storage using UserDefaults
@MainActor
class AppSettings: ObservableObject {

    // MARK: - Singleton
    static let shared = AppSettings()

    // MARK: - Feature Toggles

    @AppStorage("screenCaptureEnabled")
    var screenCaptureEnabled = false {
        didSet {
            objectWillChange.send()
            print("⚙️ Screen capture \(screenCaptureEnabled ? "enabled" : "disabled")")
        }
    }

    @AppStorage("messageMonitoringEnabled")
    var messageMonitoringEnabled = false {
        didSet {
            objectWillChange.send()
            print("⚙️ Message monitoring \(messageMonitoringEnabled ? "enabled" : "disabled")")
        }
    }

    @AppStorage("autoRespondEnabled")
    var autoRespondEnabled = false {
        didSet {
            objectWillChange.send()
            print("⚙️ Auto-respond \(autoRespondEnabled ? "enabled" : "disabled")")
        }
    }

    // MARK: - Message Processing Settings

    @AppStorage("externalProgramPath")
    var externalProgramPath = "" {
        didSet {
            objectWillChange.send()
            print("⚙️ External program path: \(externalProgramPath)")
        }
    }

    @AppStorage("processingDirectoryPath")
    var processingDirectoryPath = "\(NSHomeDirectory())/Documents/VisualAgent/Processing" {
        didSet {
            objectWillChange.send()
        }
    }

    // MARK: - Screen Capture Settings

    @AppStorage("screenCaptureFPS")
    var screenCaptureFPS = 1.0 {
        didSet {
            objectWillChange.send()
        }
    }

    @AppStorage("enableTextExtraction")
    var enableTextExtraction = true {
        didSet {
            objectWillChange.send()
        }
    }

    @AppStorage("enableAccessibilityAnalysis")
    var enableAccessibilityAnalysis = true {
        didSet {
            objectWillChange.send()
        }
    }

    // MARK: - Privacy Settings

    @AppStorage("saveScreenshots")
    var saveScreenshots = false {
        didSet {
            objectWillChange.send()
        }
    }

    @AppStorage("saveMessageHistory")
    var saveMessageHistory = false {
        didSet {
            objectWillChange.send()
        }
    }

    // MARK: - Initialization

    private init() {
        print("⚙️ AppSettings initialized")
        print("   Screen Capture: \(screenCaptureEnabled ? "ON" : "OFF")")
        print("   Message Monitoring: \(messageMonitoringEnabled ? "ON" : "OFF")")
        print("   Auto-Respond: \(autoRespondEnabled ? "ON" : "OFF")")
    }

    // MARK: - Helper Methods

    func resetToDefaults() {
        screenCaptureEnabled = false
        messageMonitoringEnabled = false
        autoRespondEnabled = false
        externalProgramPath = ""
        processingDirectoryPath = "\(NSHomeDirectory())/Documents/VisualAgent/Processing"
        screenCaptureFPS = 1.0
        enableTextExtraction = true
        enableAccessibilityAnalysis = true
        saveScreenshots = false
        saveMessageHistory = false

        print("⚙️ Settings reset to defaults")
    }

    func validateSettings() -> [String] {
        var warnings: [String] = []

        if screenCaptureEnabled && !hasScreenRecordingPermission() {
            warnings.append("Screen capture enabled but permission not granted")
        }

        if messageMonitoringEnabled && !hasAccessibilityPermission() {
            warnings.append("Message monitoring enabled but Accessibility permission not granted")
        }

        if autoRespondEnabled && !hasAppleScriptSetup() {
            warnings.append("Auto-respond enabled but AppleScript not configured")
        }

        if !externalProgramPath.isEmpty && !FileManager.default.fileExists(atPath: externalProgramPath) {
            warnings.append("External program path does not exist")
        }

        return warnings
    }

    // MARK: - Permission Checks

    private func hasScreenRecordingPermission() -> Bool {
        // Note: This is a simplified check
        // Actual permission check happens in ScreenCaptureManager
        return true
    }

    private func hasAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }

    private func hasAppleScriptSetup() -> Bool {
        let scriptPath = FileManager.default.urls(
            for: .applicationScriptsDirectory,
            in: .userDomainMask
        ).first?.appendingPathComponent("sendMessage.scpt")

        if let path = scriptPath {
            return FileManager.default.fileExists(atPath: path.path)
        }
        return false
    }
}
