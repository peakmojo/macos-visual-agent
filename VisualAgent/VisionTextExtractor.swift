import Foundation
@preconcurrency import Vision
import CoreGraphics
import AppKit

class VisionTextExtractor: ObservableObject {

    // MARK: - Text Extraction

    func extractText(from image: CGImage) async -> [String] {
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    print("❌ Vision text recognition failed: \(error)")
                    continuation.resume(returning: [])
                    return
                }

                let textStrings = self.processTextObservations(request.results as? [VNRecognizedTextObservation] ?? [])
                continuation.resume(returning: textStrings)
            }

            // Configure for English text only
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-US"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image)

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    print("❌ Vision request failed: \(error)")
                    continuation.resume(returning: [])
                }
            }
        }
    }

    private func processTextObservations(_ observations: [VNRecognizedTextObservation]) -> [String] {
        var textStrings: [String] = []

        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }
            textStrings.append(topCandidate.string)
        }

        return textStrings
    }

    // MARK: - Screen Description

    func generateScreenDescription(from image: CGImage) async -> String {
        let imageSize = CGSize(width: image.width, height: image.height)
        let textStrings = await extractText(from: image)
        let textRectangles = await detectTextRegions(from: image)

        // Create comprehensive screen description
        var description = """
        SCREEN CONTENT ANALYSIS
        ======================

        Display Information:
        - Resolution: \(Int(imageSize.width)) × \(Int(imageSize.height)) pixels
        - Capture Time: \(Date().formatted(.dateTime.hour().minute().second()))
        - Content Type: Full desktop display

        Text Content Analysis:
        - Text Elements Found: \(textStrings.count)
        - Text Regions Detected: \(textRectangles.count)

        """

        // Add all detected text content
        if !textStrings.isEmpty {
            description += """

            DETECTED TEXT CONTENT:
            =====================

            """

            for text in textStrings {
                description += "\(text)\n"
            }
        }

        // Add layout analysis
        description += """

        LAYOUT ANALYSIS:
        ===============
        - Screen has \(textRectangles.count) distinct text regions
        - Text density: \(textRectangles.count > 0 ? String(format: "%.1f", Double(textStrings.count) / Double(textRectangles.count)) : "0") items per region

        """

        return description
    }

    func generateScreenDescriptionWithText(from image: CGImage, textStrings: [String]) async -> String {
        let imageSize = CGSize(width: image.width, height: image.height)
        let textRectangles = await detectTextRegions(from: image)

        // Create comprehensive screen description using pre-extracted text
        var description = """
        SCREEN CONTENT ANALYSIS
        ======================

        Display Information:
        - Resolution: \(Int(imageSize.width)) × \(Int(imageSize.height)) pixels
        - Capture Time: \(Date().formatted(.dateTime.hour().minute().second()))
        - Content Type: Full desktop display

        Text Content Analysis:
        - Text Elements Found: \(textStrings.count)
        - Text Regions Detected: \(textRectangles.count)

        """

        // Add all detected text content
        if !textStrings.isEmpty {
            description += """

            DETECTED TEXT CONTENT:
            =====================

            """

            for text in textStrings {
                description += "\(text)\n"
            }
        }

        // Add layout analysis
        description += """

        LAYOUT ANALYSIS:
        ===============
        - Screen has \(textRectangles.count) distinct text regions
        - Text density: \(textRectangles.count > 0 ? String(format: "%.1f", Double(textStrings.count) / Double(textRectangles.count)) : "0") items per region

        """

        return description
    }

    func generateScreenDescriptionWithData(from image: CGImage, textStrings: [String], windowStructure: WindowStructure) async -> String {
        let imageSize = CGSize(width: image.width, height: image.height)
        let textRectangles = await detectTextRegions(from: image)

        // Create comprehensive screen description with window structure
        var description = """
        SCREEN CONTENT ANALYSIS
        ======================

        Display Information:
        - Resolution: \(Int(imageSize.width)) × \(Int(imageSize.height)) pixels
        - Capture Time: \(Date().formatted(.dateTime.hour().minute().second()))
        - Content Type: Full desktop display

        Window Structure:
        - Displays: \(windowStructure.displays.count)
        - Applications: \(windowStructure.applications.count)
        - Visible Windows: \(windowStructure.windows.filter { $0.isOnScreen }.count)

        Text Content Analysis:
        - Text Elements Found: \(textStrings.count)
        - Text Regions Detected: \(textRectangles.count)

        """

        // Add window hierarchy
        if !windowStructure.windows.isEmpty {
            description += """

            WINDOW HIERARCHY:
            ================

            """

            let visibleWindows = windowStructure.windows.filter { $0.isOnScreen }
            for window in visibleWindows {
                let appName = windowStructure.applications.first { app in
                    app.bundleIdentifier == window.owningApplicationBundleID
                }?.applicationName ?? "Unknown App"

                description += "• \(appName): \(window.title ?? "Untitled") [\(Int(window.frame.width))×\(Int(window.frame.height))]\n"
            }
        }

        // Add all detected text content
        if !textStrings.isEmpty {
            description += """

            DETECTED TEXT CONTENT:
            =====================

            """

            for text in textStrings {
                description += "\(text)\n"
            }
        }

        // Add layout analysis
        description += """

        LAYOUT ANALYSIS:
        ===============
        - Screen has \(textRectangles.count) distinct text regions
        - Text density: \(textRectangles.count > 0 ? String(format: "%.1f", Double(textStrings.count) / Double(textRectangles.count)) : "0") items per region
        - Active applications: \(windowStructure.applications.count)

        """

        return description
    }

    private func detectTextRegions(from image: CGImage) async -> [CGRect] {
        return await withCheckedContinuation { continuation in
            let request = VNDetectTextRectanglesRequest { request, error in
                if let error = error {
                    print("❌ Text region detection failed: \(error)")
                    continuation.resume(returning: [])
                    return
                }

                let rectangles = (request.results as? [VNTextObservation] ?? []).map { observation in
                    let imageSize = CGSize(width: image.width, height: image.height)
                    return VNImageRectForNormalizedRect(observation.boundingBox, Int(imageSize.width), Int(imageSize.height))
                }
                continuation.resume(returning: rectangles)
            }

            let handler = VNImageRequestHandler(cgImage: image)

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    print("❌ Text region detection request failed: \(error)")
                    continuation.resume(returning: [])
                }
            }
        }
    }
}

