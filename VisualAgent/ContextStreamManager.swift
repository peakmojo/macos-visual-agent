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
    @Published var coreMLStats = CoreMLStats()

    // MARK: - Core Components
    private var screenCaptureManager: ScreenCaptureManager?
    private let visionTextExtractor = VisionTextExtractor()
    private let accessibilityAnalyzer = AccessibilityAnalyzer()
    private var coreMLScreenDescriber: CoreMLScreenDescriber?
    // Mouse event recording disabled to prevent interference with mouse functionality
    // private let mouseEventRecorder = MouseEventRecorder()

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

        // Initialize CoreML screen describer
        if #available(macOS 12.0, *) {
            coreMLScreenDescriber = CoreMLScreenDescriber()
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

        // Mouse event recording disabled to prevent interference with mouse functionality
        // mouseEventRecorder.startRecording()

        isStreaming = true
        print("🚀 Context streaming started")
    }

    func stopStreaming() {
        guard isStreaming else { return }

        if #available(macOS 12.3, *) {
            screenCaptureManager?.stopCapturing()
        }

        // Mouse event recording disabled to prevent interference with mouse functionality
        // mouseEventRecorder.stopRecording()

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
        let maxProcessingTimeWithCoreML: TimeInterval = 1.5 // Allow more time for CoreML analysis

        // Process concurrently to maintain 1 FPS
        async let textStrings = visionTextExtractor.extractText(from: image)
        async let textWithPositions = visionTextExtractor.extractTextWithPositions(from: image)
        async let uiElements = extractUIElements(from: context)
        async let windowStructure = extractWindowStructure()

        // Wait for all to complete with timeout handling
        let extractedText = await textStrings
        let extractedTextWithPositions = await textWithPositions
        let extractedUI = await uiElements
        let extractedWindows = await windowStructure

        // Check if we're approaching timeout
        let currentTime = CFAbsoluteTimeGetCurrent()
        let elapsedTime = currentTime - startTime

        var screenDescription: String

        // Always generate base description first
        let baseDescription = await visionTextExtractor.generateScreenDescriptionWithData(
            from: image,
            textStrings: extractedText,
            textElements: extractedTextWithPositions,
            windowStructure: extractedWindows,
            recentMouseEvents: []
        )

        // Try CoreML enhancement based on available time
        if elapsedTime < maxProcessingTimeWithCoreML {
            // We have time for CoreML enhancement
            if #available(macOS 12.0, *), let coreMLDescriber = coreMLScreenDescriber {
                let coreMLStartTime = CFAbsoluteTimeGetCurrent()
                print("🧠 Attempting CoreML enhancement (elapsed: \(String(format: "%.3f", elapsedTime))s)")
                screenDescription = await coreMLDescriber.enhanceScreenDescription(
                    baseDescription: baseDescription,
                    from: image,
                    textElements: extractedText,
                    windowInfo: extractedWindows,
                    uiElements: extractedUI
                )
                let coreMLTime = CFAbsoluteTimeGetCurrent() - coreMLStartTime
                await updateCoreMLStats(processingTime: coreMLTime, wasUsed: true, reason: "success")
            } else {
                screenDescription = baseDescription
                await updateCoreMLStats(processingTime: 0, wasUsed: false, reason: "unavailable")
            }
        } else if elapsedTime < maxProcessingTime {
            // Use base description without CoreML
            print("⏱️ Skipping CoreML due to time constraints (elapsed: \(String(format: "%.3f", elapsedTime))s)")
            screenDescription = baseDescription
            await updateCoreMLStats(processingTime: 0, wasUsed: false, reason: "timeout")
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

            TEXT CONTENT WITH COORDINATES:
            """

            // Add coordinates for fast mode too
            for textElement in extractedTextWithPositions {
                let x = Int(textElement.boundingBox.minX)
                let y = Int(textElement.boundingBox.minY)
                let width = Int(textElement.boundingBox.width)
                let height = Int(textElement.boundingBox.height)
                screenDescription += "\n• [\(x),\(y),\(width)×\(height)] \(textElement.text)"
            }
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
        // Use enhanced complete UI tree extraction
        return await accessibilityAnalyzer.extractCompleteUITree(from: bundleID)
    }

    private func extractWindowStructure() async -> WindowStructure {
        if #available(macOS 12.3, *) {
            return await screenCaptureManager?.getWindowStructure() ?? WindowStructure(displays: [], applications: [], windows: [])
        } else {
            return WindowStructure(displays: [], applications: [], windows: [])
        }
    }

    // MARK: - Mouse Event Correlation (Disabled)

    /*
    // Mouse event correlation disabled to prevent interference with mouse functionality
    private func correlateMouseEventsWithUI(
        mouseEvents: [MouseEventData],
        uiElements: [UIElement],
        textElements: [TextElementWithPosition],
        windowStructure: WindowStructure
    ) -> [MouseEventData] {
        return mouseEvents.map { event in
            var correlatedEvent = event

            // Only correlate click events (not movements)
            if isClickEvent(event.eventType) {
                print("🖱️ Analyzing \(event.eventTypeName) at (\(Int(event.globalLocation.x)), \(Int(event.globalLocation.y)))")

                // Find UI element at click location with priority
                if let uiElement = findUIElementAt(location: event.globalLocation, in: uiElements) {
                    correlatedEvent.associatedUIElement = "\(uiElement.elementType.rawValue): \(uiElement.displayText)"
                    print("🎯 UI Element found: \(correlatedEvent.associatedUIElement!)")
                }

                // Find nearby text at click location with precise word matching using Vision framework
                if let (textElement, specificWord) = findPreciseTextAt(location: event.globalLocation, in: textElements) {
                    correlatedEvent.associatedText = specificWord ?? textElement.text
                    if let word = specificWord {
                        print("📝 Specific word: '\(word)'")
                    } else {
                        print("📄 Text element: '\(textElement.text.prefix(30))...'")
                    }
                }

                // Find window at click location as fallback
                if correlatedEvent.associatedUIElement == nil {
                    if let window = findWindowAt(location: event.globalLocation, in: windowStructure) {
                        let appName = windowStructure.applications.first { app in
                            app.bundleIdentifier == window.owningApplicationBundleID
                        }?.applicationName ?? "Unknown App"
                        correlatedEvent.associatedUIElement = "Window: \(window.title ?? "Untitled") (\(appName))"
                        print("🪟 Window context: \(correlatedEvent.associatedUIElement!)")
                    }
                }

                // Summary log
                if correlatedEvent.associatedUIElement != nil || correlatedEvent.associatedText != nil {
                    print("✅ Click correlation complete")
                } else {
                    print("⚠️ No correlation found for click")
                }
            }

            return correlatedEvent
        }
    }
    */

    // All mouse event correlation functions disabled to prevent interference with mouse functionality
    /*
    private func isClickEvent(_ eventType: NSEvent.EventType) -> Bool {
        switch eventType {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            return true
        default:
            return false
        }
    }

    private func findUIElementAt(location: CGPoint, in uiElements: [UIElement]) -> UIElement? {
        return uiElements.first { element in
            element.frame.contains(location) && element.isVisible
        }
    }

    private func findPreciseTextAt(location: CGPoint, in textElements: [TextElementWithPosition]) -> (TextElementWithPosition, String?)? {
        // First pass: Look for exact word hits using Vision framework coordinates
        for textElement in textElements {
            for wordBox in textElement.wordBoundingBoxes {
                if wordBox.boundingBox.contains(location) {
                    print("🎯 Exact word hit: '\(wordBox.word)' at (\(Int(location.x)), \(Int(location.y)))")
                    return (textElement, wordBox.word)
                }
            }
        }

        // Second pass: Look for nearest word within close proximity (15px)
        var nearestText: TextElementWithPosition?
        var nearestDistance: CGFloat = CGFloat.greatestFiniteMagnitude
        var nearestWord: String?

        for textElement in textElements {
            // Check each word for proximity with tighter tolerance
            for wordBox in textElement.wordBoundingBoxes {
                let distance = distanceFromPoint(location, toRect: wordBox.boundingBox)
                if distance < nearestDistance && distance < 15.0 {
                    nearestDistance = distance
                    nearestText = textElement
                    nearestWord = wordBox.word
                }
            }
        }

        if let text = nearestText, let word = nearestWord {
            print("📍 Nearby word hit: '\(word)' (distance: \(Int(nearestDistance))px)")
            return (text, word)
        }

        // Third pass: Check text element bounding boxes as final fallback
        for textElement in textElements {
            let overallDistance = distanceFromPoint(location, toRect: textElement.boundingBox)
            if overallDistance < nearestDistance && overallDistance < 25.0 {
                nearestDistance = overallDistance
                nearestText = textElement
                nearestWord = nil // Use full text
            }
        }

        if let text = nearestText {
            print("📄 Text region hit: '\(text.text.prefix(20))...' (distance: \(Int(nearestDistance))px)")
            return (text, nearestWord)
        }

        print("❌ No text found near click at (\(Int(location.x)), \(Int(location.y)))")
        return nil
    }

    private func distanceFromPoint(_ point: CGPoint, toRect rect: CGRect) -> CGFloat {
        // If point is inside rectangle, distance is 0
        if rect.contains(point) {
            return 0
        }

        // Calculate distance to nearest edge
        let dx = max(0, max(rect.minX - point.x, point.x - rect.maxX))
        let dy = max(0, max(rect.minY - point.y, point.y - rect.maxY))
        return sqrt(dx * dx + dy * dy)
    }

    private func findWindowAt(location: CGPoint, in windowStructure: WindowStructure) -> WindowInfo? {
        return windowStructure.windows.first { window in
            window.isOnScreen && window.frame.contains(location)
        }
    }
    */


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

    private func updateCoreMLStats(processingTime: Double, wasUsed: Bool, reason: String) async {
        coreMLStats.totalAttempts += 1
        if wasUsed {
            coreMLStats.successfulUses += 1
            coreMLStats.averageProcessingTime = (coreMLStats.averageProcessingTime + processingTime) / 2
        }
        coreMLStats.lastReason = reason
        coreMLStats.lastAttemptTime = Date()
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

struct CoreMLStats {
    var totalAttempts: Int = 0
    var successfulUses: Int = 0
    var averageProcessingTime: Double = 0.0
    var lastReason: String = "not attempted"
    var lastAttemptTime: Date = Date()

    var successRate: Double {
        return totalAttempts > 0 ? Double(successfulUses) / Double(totalAttempts) : 0.0
    }

    var isCurrentlyWorking: Bool {
        return lastReason == "success" && Date().timeIntervalSince(lastAttemptTime) < 10
    }
}

// MARK: - Mouse Event Types (Moved here for compilation fix)

struct MouseEventData: Identifiable {
    let id = UUID()
    let timestamp: Date
    let eventType: NSEvent.EventType
    let location: CGPoint
    let globalLocation: CGPoint
    let clickCount: Int
    let deltaX: CGFloat
    let deltaY: CGFloat
    let scrollDeltaX: CGFloat
    let scrollDeltaY: CGFloat
    let modifierFlags: NSEvent.ModifierFlags
    let isGlobalEvent: Bool
    var associatedUIElement: String?
    var associatedText: String?

    var eventTypeName: String {
        switch eventType {
        case .leftMouseDown: return "Left Click"
        case .leftMouseUp: return "Left Release"
        case .rightMouseDown: return "Right Click"
        case .rightMouseUp: return "Right Release"
        case .otherMouseDown: return "Other Click"
        case .otherMouseUp: return "Other Release"
        case .mouseMoved: return "Move"
        case .leftMouseDragged: return "Left Drag"
        case .rightMouseDragged: return "Right Drag"
        case .otherMouseDragged: return "Other Drag"
        case .scrollWheel: return "Scroll"
        default: return "Other"
        }
    }

    var hasMovement: Bool {
        return deltaX != 0 || deltaY != 0
    }

    var hasScroll: Bool {
        return scrollDeltaX != 0 || scrollDeltaY != 0
    }
}

// MARK: - Text Analysis Types (Moved here for compilation fix)

struct TextElementWithPosition {
    let text: String
    let boundingBox: CGRect
    let confidence: Float
    let wordBoundingBoxes: [WordBoundingBox]

    var coordinateDescription: String {
        return "[\(Int(boundingBox.minX)),\(Int(boundingBox.minY)),\(Int(boundingBox.width))×\(Int(boundingBox.height))]"
    }

    var displayText: String {
        return text
    }
}

struct WordBoundingBox {
    let word: String
    let boundingBox: CGRect
    let range: Range<String.Index>
}

// MARK: - Mouse Event Recorder (Disabled to prevent mouse interference)

/*
class MouseEventRecorder: ObservableObject {

    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var lastMouseEvent: MouseEventData?
    @Published var eventHistory: [MouseEventData] = []

    // MARK: - Private Properties
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private let maxHistorySize = 1000

    // MARK: - Event Recording Control

    func startRecording() {
        guard !isRecording else { return }

        // Check accessibility permissions
        let accessEnabled = AXIsProcessTrustedWithOptions([
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary)

        if !accessEnabled {
            print("⚠️ Accessibility permissions required for mouse event recording")
            return
        }

        setupEventMonitors()
        isRecording = true
        print("🖱️ Started mouse event recording")
    }

    func stopRecording() {
        guard isRecording else { return }

        removeEventMonitors()
        isRecording = false
        print("🛑 Stopped mouse event recording")
    }

    private func setupEventMonitors() {
        // Global monitor for system-wide events (excluding our app)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [
            .mouseMoved,
            .leftMouseDown,
            .leftMouseUp,
            .rightMouseDown,
            .rightMouseUp,
            .otherMouseDown,
            .otherMouseUp,
            .leftMouseDragged,
            .rightMouseDragged,
            .otherMouseDragged,
            .scrollWheel
        ]) { [weak self] event in
            self?.recordMouseEvent(event, isGlobal: true)
        }

        // Local monitor for events within our app
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [
            .mouseMoved,
            .leftMouseDown,
            .leftMouseUp,
            .rightMouseDown,
            .rightMouseUp,
            .otherMouseDown,
            .otherMouseUp,
            .leftMouseDragged,
            .rightMouseDragged,
            .otherMouseDragged,
            .scrollWheel
        ]) { [weak self] event in
            self?.recordMouseEvent(event, isGlobal: false)
            return event // Return event to continue normal processing
        }
    }

    private func removeEventMonitors() {
        if let globalMonitor = globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }

        if let localMonitor = localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }

    private func recordMouseEvent(_ event: NSEvent, isGlobal: Bool) {
        let eventData = MouseEventData(
            timestamp: Date(),
            eventType: event.type,
            location: event.locationInWindow,
            globalLocation: NSEvent.mouseLocation,
            clickCount: event.clickCount,
            deltaX: event.deltaX,
            deltaY: event.deltaY,
            scrollDeltaX: event.scrollingDeltaX,
            scrollDeltaY: event.scrollingDeltaY,
            modifierFlags: event.modifierFlags,
            isGlobalEvent: isGlobal
        )

        DispatchQueue.main.async {
            self.lastMouseEvent = eventData
            self.eventHistory.append(eventData)

            // Limit history size
            if self.eventHistory.count > self.maxHistorySize {
                self.eventHistory.removeFirst(self.eventHistory.count - self.maxHistorySize)
            }
        }
    }

    // MARK: - Utility Methods

    func clearHistory() {
        eventHistory.removeAll()
        lastMouseEvent = nil
    }

    func getRecentEvents(count: Int = 10) -> [MouseEventData] {
        return Array(eventHistory.suffix(count))
    }

    func getEventsInTimeRange(seconds: TimeInterval) -> [MouseEventData] {
        let cutoffTime = Date().addingTimeInterval(-seconds)
        return eventHistory.filter { $0.timestamp >= cutoffTime }
    }

    deinit {
        stopRecording()
    }
}
*/