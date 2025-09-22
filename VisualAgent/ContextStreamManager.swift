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

        // Process concurrently
        async let textElements = visionTextExtractor.extractText(from: image)
        async let uiElements = extractUIElements(from: context)

        // Wait for both to complete
        let extractedText = await textElements
        let extractedUI = await uiElements

        // Fuse data
        let fusedElements = fuseTextAndUIElements(
            textElements: extractedText,
            uiElements: extractedUI,
            mousePosition: context.mousePosition
        )

        // Create screen context
        let screenContext = ScreenContext(
            timestamp: context.timestamp,
            captureContext: context,
            textElements: extractedText,
            uiElements: extractedUI,
            fusedElements: fusedElements,
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

    // MARK: - Data Fusion

    private func fuseTextAndUIElements(
        textElements: [TextElement],
        uiElements: [UIElement],
        mousePosition: CGPoint
    ) -> [FusedElement] {
        var fusedElements: [FusedElement] = []

        // Correlate text with UI elements based on spatial proximity
        for uiElement in uiElements.filter({ $0.isVisible }) {
            let nearbyText = findNearbyText(for: uiElement, in: textElements)
            let distanceToMouse = distance(from: mousePosition, to: uiElement.frame)

            let fusedElement = FusedElement(
                uiElement: uiElement,
                associatedText: nearbyText,
                distanceToMouse: distanceToMouse,
                interactionProbability: calculateInteractionProbability(
                    uiElement: uiElement,
                    nearbyText: nearbyText,
                    mouseDistance: distanceToMouse
                )
            )

            fusedElements.append(fusedElement)
        }

        // Add standalone text elements (not associated with UI)
        for textElement in textElements {
            if !fusedElements.contains(where: { element in
                element.associatedText.contains { text in text.id == textElement.id }
            }) {
                let distanceToMouse = distance(from: mousePosition, to: textElement.boundingBox)

                let fusedElement = FusedElement(
                    uiElement: nil,
                    associatedText: [textElement],
                    distanceToMouse: distanceToMouse,
                    interactionProbability: textElement.isPossibleButton ? 0.6 : 0.2
                )

                fusedElements.append(fusedElement)
            }
        }

        return fusedElements.sorted { $0.interactionProbability > $1.interactionProbability }
    }

    private func findNearbyText(for uiElement: UIElement, in textElements: [TextElement]) -> [TextElement] {
        let threshold: CGFloat = 50.0

        return textElements.filter { textElement in
            let distance = minimumDistance(between: uiElement.frame, and: textElement.boundingBox)
            return distance <= threshold
        }
    }

    private func calculateInteractionProbability(
        uiElement: UIElement?,
        nearbyText: [TextElement],
        mouseDistance: CGFloat
    ) -> Double {
        var probability: Double = 0.0

        // Base probability from UI element type
        if let ui = uiElement {
            switch ui.elementType {
            case .button: probability += 0.8
            case .textInput: probability += 0.7
            case .checkbox, .radioButton: probability += 0.6
            case .dropdown, .menu: probability += 0.5
            case .link: probability += 0.4
            default: probability += 0.2
            }

            // Enabled state
            if ui.enabled {
                probability += 0.1
            } else {
                probability -= 0.3
            }
        }

        // Text analysis boost
        for text in nearbyText {
            if text.isPossibleButton {
                probability += 0.3
            }
            if text.confidence > 0.9 {
                probability += 0.1
            }
        }

        // Mouse proximity (closer = higher probability)
        let maxDistance: CGFloat = 200.0
        let proximityBoost = max(0, (maxDistance - mouseDistance) / maxDistance) * 0.2
        probability += proximityBoost

        return min(1.0, max(0.0, probability))
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
    let textElements: [TextElement]
    let uiElements: [UIElement]
    let fusedElements: [FusedElement]
    let screenshot: CGImage

    var totalElements: Int {
        return textElements.count + uiElements.count
    }

    var topInteractionCandidates: [FusedElement] {
        return Array(fusedElements.prefix(5))
    }
}

struct FusedElement: Identifiable {
    let id = UUID()
    let uiElement: UIElement?
    let associatedText: [TextElement]
    let distanceToMouse: CGFloat
    let interactionProbability: Double

    var displayText: String {
        if let ui = uiElement {
            return ui.displayText
        } else if let firstText = associatedText.first {
            return firstText.text
        } else {
            return "Unknown Element"
        }
    }

    var frame: CGRect {
        if let ui = uiElement {
            return ui.frame
        } else if let firstText = associatedText.first {
            return firstText.boundingBox
        } else {
            return .zero
        }
    }
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