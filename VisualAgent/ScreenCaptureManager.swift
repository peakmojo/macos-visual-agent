import Foundation
@preconcurrency import ScreenCaptureKit
import CoreGraphics
import AppKit

@available(macOS 12.3, *)
class ScreenCaptureManager: NSObject, ObservableObject {
    private var stream: SCStream?
    private var availableContent: SCShareableContent?
    private var isCapturing = false

    // Configuration
    private let captureInterval: TimeInterval = 0.5 // 2 FPS
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

        // Priority 1: Try to capture focused window
        if let focusedWindow = getFocusedWindow(from: availableContent) {
            await captureWindow(focusedWindow, context: context)
        } else {
            // Fallback: Capture main display
            if let mainDisplay = availableContent.displays.first {
                await captureDisplay(mainDisplay, context: context)
            }
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

    // MARK: - Window Capture

    private func captureWindow(_ window: SCWindow, context: CaptureContext) async {
        let config = SCStreamConfiguration()
        config.width = Int(window.frame.width)
        config.height = Int(window.frame.height)
        config.capturesAudio = false
        config.sampleRate = 2 // 2 FPS
        config.minimumFrameInterval = CMTime(value: 1, timescale: 2)

        let filter = SCContentFilter(desktopIndependentWindow: window)

        do {
            let stream = SCStream(filter: filter, configuration: config, delegate: nil)

            // Add stream output
            try stream.addStreamOutput(CaptureOutput(onFrame: { [weak self] cgImage in
                var updatedContext = context
                updatedContext.captureType = .window(window)
                updatedContext.captureArea = window.frame
                self?.onScreenCaptured?(cgImage, updatedContext)
            }), type: .screen, sampleHandlerQueue: DispatchQueue.global(qos: .userInitiated))

            try await stream.startCapture()

            // Stop after capturing one frame
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                Task {
                    try? await stream.stopCapture()
                }
            }

        } catch {
            print("❌ Window capture failed: \(error)")
        }
    }

    // MARK: - Display Capture

    private func captureDisplay(_ display: SCDisplay, context: CaptureContext) async {
        let config = SCStreamConfiguration()
        config.width = display.width
        config.height = display.height
        config.capturesAudio = false
        config.sampleRate = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 2)

        let filter = SCContentFilter(display: display, excludingWindows: [])

        do {
            let stream = SCStream(filter: filter, configuration: config, delegate: nil)

            try stream.addStreamOutput(CaptureOutput(onFrame: { [weak self] cgImage in
                var updatedContext = context
                updatedContext.captureType = .display(display)
                updatedContext.captureArea = CGRect(x: 0, y: 0, width: display.width, height: display.height)
                self?.onScreenCaptured?(cgImage, updatedContext)
            }), type: .screen, sampleHandlerQueue: DispatchQueue.global(qos: .userInitiated))

            try await stream.startCapture()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                Task {
                    try? await stream.stopCapture()
                }
            }

        } catch {
            print("❌ Display capture failed: \(error)")
        }
    }

    deinit {
        stopCapturing()
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