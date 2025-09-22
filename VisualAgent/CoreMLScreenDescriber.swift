import Foundation
import CoreML
import Vision
import CoreGraphics
import AppKit
import UniformTypeIdentifiers

@available(macOS 12.0, *)
class CoreMLScreenDescriber: ObservableObject, @unchecked Sendable {

    // MARK: - Published Properties
    @Published var isModelLoaded = false
    @Published var lastDescription: String?
    @Published var isProcessing = false

    // MARK: - Private Properties
    private let processingQueue = DispatchQueue(label: "screen.description", qos: .userInitiated)

    // Using Vision classification directly in processing methods

    // MARK: - Initialization

    init() {
        loadCoreMLModel()
    }

    // MARK: - Model Loading

    private func loadCoreMLModel() {
        processingQueue.async { [weak self] in
            self?.loadCustomImageCaptioningModel()
        }
    }

    private func loadCustomImageCaptioningModel() {
        // For now, we'll use Apple's built-in Vision image classification
        // This provides a solid foundation for screen understanding
        // Custom CoreML models can be added later as needed

        DispatchQueue.main.async {
            self.isModelLoaded = true
            print("✅ CoreML screen description ready (using Vision framework)")
        }
    }

    // MARK: - Screen Description Generation

    func enhanceScreenDescription(baseDescription: String,
                                  from image: CGImage,
                                  textElements: [String] = [],
                                  windowInfo: WindowStructure? = nil,
                                  uiElements: [UIElement] = []) async -> String {

        guard isModelLoaded else {
            return baseDescription
        }

        await MainActor.run {
            isProcessing = true
        }

        defer {
            Task { @MainActor in
                isProcessing = false
            }
        }

        // Enhance image analysis with CoreML + Vision
        let imageAnalysis = await analyzeImageWithCoreML(image)
        let screenContext = await analyzeScreenContext(image, textElements: textElements,
                                                      windowInfo: windowInfo, uiElements: uiElements)

        // Combine original description with CoreML insights
        let enhancedDescription = combineDescriptions(
            baseDescription: baseDescription,
            imageAnalysis: imageAnalysis,
            screenContext: screenContext,
            textElements: textElements,
            windowInfo: windowInfo,
            uiElements: uiElements
        )

        await MainActor.run {
            lastDescription = enhancedDescription
        }

        return enhancedDescription
    }

    // MARK: - CoreML Analysis

    private func analyzeImageWithCoreML(_ image: CGImage) async -> ImageAnalysisResult {
        return await withCheckedContinuation { continuation in

            // Use built-in image classification for now (simpler and more compatible)
            let handler = VNImageRequestHandler(cgImage: image)

            let classificationRequest = VNClassifyImageRequest { request, error in
                if let error = error {
                    print("❌ Image classification failed: \(error)")
                    continuation.resume(returning: ImageAnalysisResult.fallback())
                    return
                }

                let result = self.processClassificationResults(request.results as? [VNClassificationObservation] ?? [])
                continuation.resume(returning: result)
            }

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([classificationRequest])
                } catch {
                    print("❌ Classification request failed: \(error)")
                    continuation.resume(returning: ImageAnalysisResult.fallback())
                }
            }
        }
    }

    private func analyzeScreenContext(_ image: CGImage,
                                     textElements: [String],
                                     windowInfo: WindowStructure?,
                                     uiElements: [UIElement]) async -> ScreenContextAnalysis {

        // Determine screen type and dominant interface patterns
        let screenType = determineScreenType(textElements: textElements,
                                           windowInfo: windowInfo,
                                           uiElements: uiElements)

        // Analyze UI layout patterns
        let layoutAnalysis = analyzeUILayout(uiElements: uiElements, imageSize: CGSize(width: image.width, height: image.height))

        // Analyze content density and complexity
        let contentAnalysis = analyzeContentDensity(textElements: textElements, uiElements: uiElements)

        return ScreenContextAnalysis(
            screenType: screenType,
            layoutAnalysis: layoutAnalysis,
            contentAnalysis: contentAnalysis,
            dominantApplication: windowInfo?.applications.first?.applicationName
        )
    }

    // MARK: - Result Processing

    // Note: Custom model processing removed for API compatibility
    // Can be re-added when specific CoreML models are integrated

    private func processClassificationResults(_ observations: [VNClassificationObservation]) -> ImageAnalysisResult {
        let topObservations = Array(observations.prefix(5))
        let primaryObjects = topObservations.map { $0.identifier }
        let averageConfidence = topObservations.reduce(0.0) { $0 + Double($1.confidence) } / Double(max(topObservations.count, 1))

        // Adapt classification results for screen context
        let screenRelevantObjects = adaptForScreenContext(primaryObjects)
        let sceneDescription = generateSceneDescription(from: screenRelevantObjects)
        let complexity = determineVisualComplexity(observations: topObservations)

        return ImageAnalysisResult(
            primaryObjects: screenRelevantObjects,
            confidence: averageConfidence,
            sceneDescription: sceneDescription,
            visualComplexity: complexity
        )
    }

    // Note: Async classification results handled directly in continuation

    // MARK: - Context Analysis

    private func determineScreenType(textElements: [String],
                                   windowInfo: WindowStructure?,
                                   uiElements: [UIElement]) -> ScreenType {

        // Analyze patterns to determine screen type
        let hasCode = textElements.contains { element in
            element.contains("function") || element.contains("import") || element.contains("class") ||
            element.contains("{") || element.contains("}")
        }

        let hasWebContent = textElements.contains { element in
            element.contains("http") || element.contains("www.") || element.lowercased().contains("search")
        }

        let hasDesignTools = windowInfo?.applications.contains { app in
            ["Figma", "Sketch", "Adobe", "Photoshop", "Illustrator"].contains {
                app.applicationName.contains($0)
            }
        } ?? false

        if hasCode {
            return .development
        } else if hasWebContent {
            return .web
        } else if hasDesignTools {
            return .design
        } else {
            return .general
        }
    }

    private func analyzeUILayout(uiElements: [UIElement], imageSize: CGSize) -> UILayoutAnalysis {
        let totalElements = uiElements.count
        let density = Double(totalElements) / (Double(imageSize.width * imageSize.height) / 10000.0)

        let hasMenu = uiElements.contains { $0.elementType == .menu }
        let hasToolbar = uiElements.contains { $0.role.contains("Toolbar") }
        let hasSidebar = uiElements.contains { $0.role.lowercased().contains("sidebar") || $0.title?.lowercased().contains("sidebar") == true }

        return UILayoutAnalysis(
            elementDensity: density,
            hasMenuBar: hasMenu,
            hasToolbar: hasToolbar,
            hasSidebar: hasSidebar,
            layoutPattern: determineLayoutPattern(uiElements)
        )
    }

    private func analyzeContentDensity(textElements: [String], uiElements: [UIElement]) -> ContentAnalysis {
        let totalTextLength = textElements.reduce(0) { $0 + $1.count }
        let averageTextLength = totalTextLength / max(textElements.count, 1)

        let interactiveElements = uiElements.filter { element in
            [.button, .textInput, .slider, .checkbox].contains(element.elementType)
        }.count

        return ContentAnalysis(
            textDensity: Double(totalTextLength),
            averageTextLength: averageTextLength,
            interactiveElements: interactiveElements,
            contentComplexity: determineContentComplexity(textElements: textElements, uiElements: uiElements)
        )
    }

    // MARK: - Description Generation

    private func combineDescriptions(baseDescription: String,
                                   imageAnalysis: ImageAnalysisResult,
                                   screenContext: ScreenContextAnalysis,
                                   textElements: [String],
                                   windowInfo: WindowStructure?,
                                   uiElements: [UIElement]) -> String {

        // Start with the original text extraction description
        var enhancedDescription = baseDescription

        // Add CoreML insights as additional sections
        enhancedDescription += """


        ═══════════════════════════════════════════════════════
        🧠 AI CONTEXTUAL INSIGHTS
        ═══════════════════════════════════════════════════════

        SCREEN TYPE: \(screenContext.screenType.displayName)
        VISUAL COMPLEXITY: \(imageAnalysis.visualComplexity.displayName)
        ANALYSIS CONFIDENCE: \(String(format: "%.1f%%", imageAnalysis.confidence * 100))

        VISUAL UNDERSTANDING:
        \(imageAnalysis.sceneDescription)

        """

        // Add primary objects detected if available
        if !imageAnalysis.primaryObjects.isEmpty {
            enhancedDescription += """
            PRIMARY VISUAL ELEMENTS:
            \(imageAnalysis.primaryObjects.prefix(5).map { "• \($0)" }.joined(separator: "\n"))

            """
        }

        // Add UI layout analysis
        enhancedDescription += """
        UI LAYOUT ANALYSIS:
        • Element Density: \(String(format: "%.1f", screenContext.layoutAnalysis.elementDensity)) elements/region
        • Layout Pattern: \(screenContext.layoutAnalysis.layoutPattern.displayName)
        • Menu Bar: \(screenContext.layoutAnalysis.hasMenuBar ? "Present" : "Not detected")
        • Toolbar: \(screenContext.layoutAnalysis.hasToolbar ? "Present" : "Not detected")
        • Sidebar: \(screenContext.layoutAnalysis.hasSidebar ? "Present" : "Not detected")

        """

        // Add contextual insights
        enhancedDescription += generateContextualInsights(screenContext: screenContext,
                                                        imageAnalysis: imageAnalysis,
                                                        textElements: textElements)

        return enhancedDescription
    }

    private func generateContextualInsights(screenContext: ScreenContextAnalysis,
                                          imageAnalysis: ImageAnalysisResult,
                                          textElements: [String]) -> String {

        var insights = "CONTEXTUAL INSIGHTS:\n"

        // Screen type specific insights
        switch screenContext.screenType {
        case .development:
            insights += "• Development environment detected - likely coding activity\n"
            if textElements.contains(where: { $0.contains("error") || $0.contains("Error") }) {
                insights += "• Error messages detected in code\n"
            }
        case .web:
            insights += "• Web browsing activity detected\n"
            if textElements.contains(where: { $0.contains("search") || $0.contains("Search") }) {
                insights += "• Search activity indicated\n"
            }
        case .design:
            insights += "• Design tool usage detected\n"
        case .general:
            insights += "• General desktop activity\n"
        }

        // Complexity insights
        if imageAnalysis.visualComplexity == .high {
            insights += "• High visual complexity - dense information display\n"
        }

        if screenContext.contentAnalysis.interactiveElements > 10 {
            insights += "• Rich interactive interface with \(screenContext.contentAnalysis.interactiveElements) controls\n"
        }

        return insights
    }

    // MARK: - Helper Functions

    private func adaptForScreenContext(_ objects: [String]) -> [String] {
        // Map generic object names to screen-relevant terms
        return objects.map { object in
            switch object.lowercased() {
            case let obj where obj.contains("computer"):
                return "desktop interface"
            case let obj where obj.contains("display"):
                return "screen display"
            case let obj where obj.contains("text"):
                return "text content"
            default:
                return object
            }
        }
    }

    private func generateSceneDescription(from objects: [String]) -> String {
        if objects.isEmpty {
            return "Desktop interface with visual elements"
        }

        let primaryObject = objects.first ?? "interface"
        let additionalObjects = objects.dropFirst().prefix(2)

        if additionalObjects.isEmpty {
            return "Desktop showing \(primaryObject)"
        } else {
            return "Desktop interface featuring \(primaryObject) with \(additionalObjects.joined(separator: " and "))"
        }
    }

    private func determineVisualComplexity(observations: [VNClassificationObservation]) -> VisualComplexity {
        let averageConfidence = observations.reduce(0.0) { $0 + Double($1.confidence) } / Double(max(observations.count, 1))

        if averageConfidence < 0.3 {
            return .high // Low confidence suggests complex, hard to classify content
        } else if averageConfidence > 0.7 {
            return .low // High confidence suggests clear, simple content
        } else {
            return .medium
        }
    }

    private func determineLayoutPattern(_ uiElements: [UIElement]) -> UILayoutPattern {
        guard !uiElements.isEmpty else { return .centered }

        let hasLeftElements = uiElements.contains { $0.frame.minX < 200 }
        let hasRightElements = uiElements.contains { $0.frame.maxX > 800 }
        let hasTopElements = uiElements.contains { $0.frame.minY < 100 }

        if hasLeftElements && hasRightElements {
            return .multiColumn
        } else if hasTopElements {
            return .topDown
        } else {
            return .centered
        }
    }

    private func determineContentComplexity(textElements: [String], uiElements: [UIElement]) -> ContentComplexity {
        let totalContent = textElements.count + uiElements.count

        if totalContent > 50 {
            return .high
        } else if totalContent > 20 {
            return .medium
        } else {
            return .low
        }
    }
}

// MARK: - Supporting Types

struct ImageAnalysisResult {
    let primaryObjects: [String]
    let confidence: Double
    let sceneDescription: String
    let visualComplexity: VisualComplexity

    static func fallback() -> ImageAnalysisResult {
        return ImageAnalysisResult(
            primaryObjects: ["desktop interface"],
            confidence: 0.5,
            sceneDescription: "Desktop interface with various UI elements",
            visualComplexity: .medium
        )
    }
}

struct ScreenContextAnalysis {
    let screenType: ScreenType
    let layoutAnalysis: UILayoutAnalysis
    let contentAnalysis: ContentAnalysis
    let dominantApplication: String?
}

struct UILayoutAnalysis {
    let elementDensity: Double
    let hasMenuBar: Bool
    let hasToolbar: Bool
    let hasSidebar: Bool
    let layoutPattern: UILayoutPattern
}

struct ContentAnalysis {
    let textDensity: Double
    let averageTextLength: Int
    let interactiveElements: Int
    let contentComplexity: ContentComplexity
}

enum ScreenType {
    case development
    case web
    case design
    case general

    var displayName: String {
        switch self {
        case .development: return "Development Environment"
        case .web: return "Web Browser"
        case .design: return "Design Tool"
        case .general: return "General Desktop"
        }
    }
}

enum VisualComplexity {
    case low
    case medium
    case high

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}

enum UILayoutPattern {
    case topDown
    case multiColumn
    case centered

    var displayName: String {
        switch self {
        case .topDown: return "Top-Down"
        case .multiColumn: return "Multi-Column"
        case .centered: return "Centered"
        }
    }
}

enum ContentComplexity {
    case low
    case medium
    case high

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}