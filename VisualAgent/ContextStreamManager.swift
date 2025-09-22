import Foundation
import CoreGraphics
import Combine
import AppKit

@MainActor
class ContextStreamManager: ObservableObject {

    // MARK: - Published Properties
    @Published var currentContext: ScreenContext?
    @Published var isStreaming = false
    @Published var lastUpdateTime: Date?
    @Published var processingStats = ProcessingStats()

    // MARK: - Core Components
    private var screenCaptureManager: ScreenCaptureManager?
    private let visionTextExtractor = VisionTextExtractor()
    private let accessibilityAnalyzer = AccessibilityAnalyzer()

    // MARK: - Streaming Configuration
    private let streamingQueue = DispatchQueue(label: "context.streaming", qos: .userInitiated)
    private var contextCache: [String: CachedContext] = [:]
    private let cacheExpirationInterval: TimeInterval = 5.0

    // MARK: - Callbacks
    var onContextUpdate: ((ScreenContext) -> Void)?

    // MARK: - Initialization

    init() {
        setupComponents()
    }

    private func setupComponents() {
        if #available(macOS 12.3, *) {
            screenCaptureManager = ScreenCaptureManager()
            screenCaptureManager?.onScreenCaptured = { [weak self] image, captureContext in
                Task { @MainActor in
                    await self?.processScreenCapture(image: image, context: captureContext)
                }
            }
        } else {
            print("⚠️ ScreenCaptureKit requires macOS 12.3+")
        }
    }

    // MARK: - Stream Control

    func startStreaming() async {
        guard !isStreaming else { return }

        // Check permissions
        if !accessibilityAnalyzer.checkAccessibilityPermission() {
            accessibilityAnalyzer.requestAccessibilityPermission()
            return
        }

        if #available(macOS 12.3, *) {
            await screenCaptureManager?.requestPermissions()
            screenCaptureManager?.startCapturing()
        }

        isStreaming = true
        print("🚀 Context streaming started")
    }

    func stopStreaming() {
        guard isStreaming else { return }

        if #available(macOS 12.3, *) {
            screenCaptureManager?.stopCapturing()
        }

        isStreaming = false
        print("⏹️ Context streaming stopped")
    }

    // MARK: - Core Processing Pipeline

    private func processScreenCapture(image: CGImage, context: CaptureContext) async {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Check cache first
        let cacheKey = generateCacheKey(from: context)
        if let cachedContext = getCachedContext(for: cacheKey) {
            await updateCurrentContext(cachedContext.screenContext)
            return
        }

        // Ensure processing doesn't exceed 1 second to maintain 1 FPS
        let maxProcessingTime: TimeInterval = 0.9 // Leave 0.1s buffer

        // Process concurrently to maintain 1 FPS
        async let textStrings = visionTextExtractor.extractText(from: image)
        async let uiElements = extractUIElements(from: context)
        async let windowStructure = extractWindowStructure()

        // Wait for all to complete with timeout handling
        let extractedText = await textStrings
        let extractedUI = await uiElements
        let extractedWindows = await windowStructure

        // Check if we're approaching timeout
        let currentTime = CFAbsoluteTimeGetCurrent()
        let elapsedTime = currentTime - startTime

        let screenDescription: String
        if elapsedTime < maxProcessingTime {
            // Generate screen description with already extracted text and windows
            screenDescription = await visionTextExtractor.generateScreenDescriptionWithData(
                from: image,
                textStrings: extractedText,
                windowStructure: extractedWindows
            )
        } else {
            // Use simple description to maintain 1 FPS
            let imageSize = CGSize(width: image.width, height: image.height)
            screenDescription = """
            SCREEN CONTENT ANALYSIS (Fast Mode)
            ===================================

            Display: \(Int(imageSize.width)) × \(Int(imageSize.height)) pixels
            Time: \(Date().formatted(.dateTime.hour().minute().second()))
            Text Elements: \(extractedText.count)
            UI Elements: \(extractedUI.count)

            TEXT CONTENT:
            \(extractedText.joined(separator: "\n"))
            """
        }

        // Create simplified screen context
        let screenContext = ScreenContext(
            timestamp: context.timestamp,
            captureContext: context,
            screenDescription: screenDescription,
            textStrings: extractedText,
            uiElements: extractedUI,
            windowStructure: extractedWindows,
            screenshot: image
        )

        // Cache result
        cacheContext(screenContext, for: cacheKey)

        // Update stats
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        await updateProcessingStats(processingTime: processingTime,
                                  textCount: extractedText.count,
                                  uiCount: extractedUI.count)

        // Notify observers
        await updateCurrentContext(screenContext)
        onContextUpdate?(screenContext)
    }

    private func extractUIElements(from context: CaptureContext) async -> [UIElement] {
        guard let bundleID = context.frontmostAppBundleID else { return [] }
        return await accessibilityAnalyzer.extractUIElements(from: bundleID)
    }

    private func extractWindowStructure() async -> WindowStructure {
        if #available(macOS 12.3, *) {
            return await screenCaptureManager?.getWindowStructure() ?? WindowStructure(displays: [], applications: [], windows: [])
        } else {
            return WindowStructure(displays: [], applications: [], windows: [])
        }
    }


    // MARK: - Caching

    private func generateCacheKey(from context: CaptureContext) -> String {
        let appID = context.frontmostAppBundleID ?? "unknown"
        let mouseRegion = "\(Int(context.mousePosition.x / 100))_\(Int(context.mousePosition.y / 100))"
        return "\(appID)_\(mouseRegion)"
    }

    private func getCachedContext(for key: String) -> CachedContext? {
        guard let cached = contextCache[key],
              Date().timeIntervalSince(cached.timestamp) < cacheExpirationInterval else {
            return nil
        }
        return cached
    }

    private func cacheContext(_ context: ScreenContext, for key: String) {
        contextCache[key] = CachedContext(screenContext: context, timestamp: Date())

        // Clean expired cache entries
        contextCache = contextCache.filter { _, cached in
            Date().timeIntervalSince(cached.timestamp) < cacheExpirationInterval
        }
    }

    // MARK: - Helper Functions

    private func distance(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let dx = point.x - center.x
        let dy = point.y - center.y
        return sqrt(dx * dx + dy * dy)
    }

    private func minimumDistance(between rect1: CGRect, and rect2: CGRect) -> CGFloat {
        let dx = max(0, max(rect1.minX - rect2.maxX, rect2.minX - rect1.maxX))
        let dy = max(0, max(rect1.minY - rect2.maxY, rect2.minY - rect1.maxY))
        return sqrt(dx * dx + dy * dy)
    }

    private func updateCurrentContext(_ context: ScreenContext) async {
        currentContext = context
        lastUpdateTime = Date()
    }

    private func updateProcessingStats(processingTime: Double, textCount: Int, uiCount: Int) async {
        processingStats.averageProcessingTime = (processingStats.averageProcessingTime + processingTime) / 2
        processingStats.lastTextElementCount = textCount
        processingStats.lastUIElementCount = uiCount
        processingStats.totalUpdates += 1
    }
}

// MARK: - Supporting Types

struct ScreenContext {
    let timestamp: Date
    let captureContext: CaptureContext
    let screenDescription: String
    let textStrings: [String]
    let uiElements: [UIElement]
    let windowStructure: WindowStructure
    let screenshot: CGImage

    var totalElements: Int {
        return textStrings.count + uiElements.count + windowStructure.windows.count
    }
}

struct WindowStructure {
    let displays: [DisplayInfo]
    let applications: [ApplicationInfo]
    let windows: [WindowInfo]
}

struct DisplayInfo {
    let id: UInt32
    let width: Int
    let height: Int
}

struct ApplicationInfo {
    let bundleIdentifier: String
    let applicationName: String
    let processIdentifier: pid_t
}

struct WindowInfo {
    let windowID: UInt32
    let title: String?
    let frame: CGRect
    let isOnScreen: Bool
    let owningApplicationBundleID: String?
}

struct CachedContext {
    let screenContext: ScreenContext
    let timestamp: Date
}

struct ProcessingStats {
    var averageProcessingTime: Double = 0.0
    var lastTextElementCount: Int = 0
    var lastUIElementCount: Int = 0
    var totalUpdates: Int = 0

    var fps: Double {
        return totalUpdates > 0 ? 1.0 / averageProcessingTime : 0.0
    }
}