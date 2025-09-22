import Foundation
@preconcurrency import ScreenCaptureKit
import CoreGraphics
import AppKit

@available(macOS 12.3, *)
class ScreenCaptureManager: NSObject, ObservableObject, SCStreamDelegate {
    private var currentStream: SCStream?
    private var availableContent: SCShareableContent?
    private var isCapturing = false
    private var captureOutput: CaptureOutput?

    // Configuration
    private let captureInterval: TimeInterval = 1.0 // 1 FPS
    private var captureTimer: Timer?

    // Capture callbacks
    var onScreenCaptured: ((CGImage, CaptureContext) -> Void)?

    override init() {
        super.init()
        Task {
            await requestPermissions()
            await updateAvailableContent()
        }
    }

    // MARK: - Permission Management

    func requestPermissions() async {
        do {
            // Request screen recording permission
            let available = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            print("✅ Screen recording permission granted")
        } catch {
            print("❌ Screen recording permission denied: \(error)")
        }
    }

    private func updateAvailableContent() async {
        do {
            availableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            print("📱 Available content updated: \(availableContent?.windows.count ?? 0) windows")
        } catch {
            print("❌ Failed to get available content: \(error)")
        }
    }

    // MARK: - Capture Control

    func startCapturing() {
        guard !isCapturing else { return }

        captureTimer = Timer.scheduledTimer(withTimeInterval: captureInterval, repeats: true) { _ in
            Task {
                await self.captureCurrentContext()
            }
        }

        isCapturing = true
        print("🎥 Started screen capturing at \(1.0/captureInterval) FPS")
    }

    func stopCapturing() {
        captureTimer?.invalidate()
        captureTimer = nil

        // Stop current stream properly
        if let stream = currentStream {
            Task {
                try? await stream.stopCapture()
                self.currentStream = nil
                self.captureOutput = nil
            }
        }

        isCapturing = false
        print("⏹️ Stopped screen capturing")
    }

    // MARK: - Core Capture Logic

    private func captureCurrentContext() async {
        guard let availableContent = availableContent else {
            await updateAvailableContent()
            return
        }

        // Get current context
        let context = getCurrentContext()

        // Always capture entire main display for comprehensive screen description
        if let mainDisplay = availableContent.displays.first {
            await setupStreamIfNeeded(for: mainDisplay, context: context)
        }
    }

    private func getFocusedWindow(from content: SCShareableContent) -> SCWindow? {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else { return nil }

        // Find the frontmost window of the active application
        return content.windows.first { window in
            window.owningApplication?.bundleIdentifier == frontmostApp.bundleIdentifier &&
            window.isOnScreen &&
            window.frame.width > 100 && window.frame.height > 100 // Filter out tiny windows
        }
    }

    private func getCurrentContext() -> CaptureContext {
        let mouseLocation = NSEvent.mouseLocation
        let frontmostApp = NSWorkspace.shared.frontmostApplication

        return CaptureContext(
            timestamp: Date(),
            mousePosition: CGPoint(x: mouseLocation.x, y: mouseLocation.y),
            frontmostAppBundleID: frontmostApp?.bundleIdentifier,
            frontmostAppName: frontmostApp?.localizedName
        )
    }

    // MARK: - Stable Stream Management

    private func setupStreamIfNeeded(for window: SCWindow, context: CaptureContext) async {
        // Stop existing stream if different window
        if currentStream != nil {
            try? await currentStream?.stopCapture()
            currentStream = nil
            captureOutput = nil
        }

        let config = SCStreamConfiguration()
        config.width = min(Int(window.frame.width), 1920) // Limit resolution
        config.height = min(Int(window.frame.height), 1080)
        config.capturesAudio = false
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1) // 1 FPS

        let filter = SCContentFilter(desktopIndependentWindow: window)

        do {
            let stream = SCStream(filter: filter, configuration: config, delegate: self)

            // Create persistent output handler
            let output = CaptureOutput(onFrame: { [weak self] cgImage in
                let currentContext = self?.getCurrentContext() ?? context
                var updatedContext = currentContext
                updatedContext.captureType = .window(window)
                updatedContext.captureArea = window.frame
                self?.onScreenCaptured?(cgImage, updatedContext)
            })

            try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: DispatchQueue.global(qos: .userInitiated))
            try await stream.startCapture()

            // Store references to keep them alive
            self.currentStream = stream
            self.captureOutput = output

        } catch {
            print("❌ Stream setup failed: \(error)")
        }
    }

    private func setupStreamIfNeeded(for display: SCDisplay, context: CaptureContext) async {
        // Stop existing stream if different display
        if currentStream != nil {
            try? await currentStream?.stopCapture()
            currentStream = nil
            captureOutput = nil
        }

        let config = SCStreamConfiguration()
        config.width = min(display.width, 1920) // Limit resolution
        config.height = min(display.height, 1080)
        config.capturesAudio = false
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1) // 1 FPS

        // Filter out Visual Agent windows
        let visualAgentWindows = availableContent?.windows.filter { window in
            window.owningApplication?.bundleIdentifier.contains("VisualAgent") == true ||
            window.title?.contains("Visual Agent") == true
        } ?? []

        let filter = SCContentFilter(display: display, excludingWindows: visualAgentWindows)

        do {
            let stream = SCStream(filter: filter, configuration: config, delegate: self)

            // Create persistent output handler
            let output = CaptureOutput(onFrame: { [weak self] cgImage in
                let currentContext = self?.getCurrentContext() ?? context
                var updatedContext = currentContext
                updatedContext.captureType = .display(display)
                updatedContext.captureArea = CGRect(x: 0, y: 0, width: display.width, height: display.height)
                self?.onScreenCaptured?(cgImage, updatedContext)
            })

            try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: DispatchQueue.global(qos: .userInitiated))
            try await stream.startCapture()

            // Store references to keep them alive
            self.currentStream = stream
            self.captureOutput = output

        } catch {
            print("❌ Stream setup failed: \(error)")
        }
    }

    // MARK: - Window Structure Extraction

    func getWindowStructure() async -> WindowStructure {
        var content = availableContent
        if content == nil {
            await updateAvailableContent()
            content = availableContent
        }

        guard let content = content else {
            return WindowStructure(displays: [], applications: [], windows: [])
        }

        // Extract display information
        let displays = content.displays.map { display in
            DisplayInfo(
                id: display.displayID,
                width: display.width,
                height: display.height
            )
        }

        // Extract application information
        let applications = content.applications.map { app in
            ApplicationInfo(
                bundleIdentifier: app.bundleIdentifier,
                applicationName: app.applicationName,
                processIdentifier: app.processID
            )
        }

        // Extract window information (excluding Visual Agent)
        let windows = content.windows.compactMap { window -> WindowInfo? in
            // Filter out Visual Agent windows
            if window.owningApplication?.bundleIdentifier.contains("VisualAgent") == true ||
               window.title?.contains("Visual Agent") == true {
                return nil
            }

            return WindowInfo(
                windowID: window.windowID,
                title: window.title,
                frame: window.frame,
                isOnScreen: window.isOnScreen,
                owningApplicationBundleID: window.owningApplication?.bundleIdentifier
            )
        }

        return WindowStructure(
            displays: displays,
            applications: applications,
            windows: windows
        )
    }

    deinit {
        stopCapturing()
    }

    // MARK: - SCStreamDelegate

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("⚠️ Stream stopped with error: \(error)")
        // Auto-restart stream if needed
        Task {
            await self.updateAvailableContent()
        }
    }
}

// MARK: - Supporting Types

struct CaptureContext: Sendable {
    let timestamp: Date
    let mousePosition: CGPoint
    let frontmostAppBundleID: String?
    let frontmostAppName: String?
    var captureType: CaptureType?
    var captureArea: CGRect?
}

enum CaptureType: Sendable {
    case window(SCWindow)
    case display(SCDisplay)
}

// MARK: - Stream Output Handler

@available(macOS 12.3, *)
class CaptureOutput: NSObject, SCStreamOutput, @unchecked Sendable {
    private let onFrame: (CGImage) -> Void

    init(onFrame: @escaping (CGImage) -> Void) {
        self.onFrame = onFrame
        super.init()
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let context = CIContext()

        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            DispatchQueue.main.async {
                self.onFrame(cgImage)
            }
        }
    }
}