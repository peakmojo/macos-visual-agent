import Foundation
@preconcurrency import Vision
import CoreGraphics
import AppKit

class VisionTextExtractor: ObservableObject, @unchecked Sendable {

    // MARK: - Text Extraction

    func extractText(from image: CGImage) async -> [String] {
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    print("❌ Vision text recognition failed: \(error)")
                    continuation.resume(returning: [])
                    return
                }

                let textStrings = self.processTextObservations(request.results as? [VNRecognizedTextObservation] ?? [], imageSize: CGSize(width: image.width, height: image.height))
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

    private func processTextObservations(_ observations: [VNRecognizedTextObservation], imageSize: CGSize) -> [String] {
        var textStrings: [String] = []

        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }
            textStrings.append(topCandidate.string)
        }

        return textStrings
    }

    // MARK: - Enhanced Text Extraction with Positions

    func extractTextWithPositions(from image: CGImage) async -> [TextElementWithPosition] {
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    print("❌ Vision text recognition failed: \(error)")
                    continuation.resume(returning: [])
                    return
                }

                let textElements = self.processTextObservationsWithPositions(request.results as? [VNRecognizedTextObservation] ?? [], imageSize: CGSize(width: image.width, height: image.height))
                continuation.resume(returning: textElements)
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

    private func processTextObservationsWithPositions(_ observations: [VNRecognizedTextObservation], imageSize: CGSize) -> [TextElementWithPosition] {
        var textElements: [TextElementWithPosition] = []

        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }

            // Convert Vision coordinates to screen coordinates for overall text
            let boundingBox = observation.boundingBox
            let rect = VNImageRectForNormalizedRect(boundingBox, Int(imageSize.width), Int(imageSize.height))

            // Extract word-level bounding boxes using Vision API
            let wordBoundingBoxes = extractWordBoundingBoxes(
                from: topCandidate,
                imageSize: imageSize
            )

            let textElement = TextElementWithPosition(
                text: topCandidate.string,
                boundingBox: rect,
                confidence: topCandidate.confidence,
                wordBoundingBoxes: wordBoundingBoxes
            )

            textElements.append(textElement)
        }

        return textElements
    }

    private func extractWordBoundingBoxes(from recognizedText: VNRecognizedText, imageSize: CGSize) -> [WordBoundingBox] {
        var wordBoxes: [WordBoundingBox] = []
        let fullText = recognizedText.string

        // Use character-by-character approach to find word boundaries more precisely
        var currentWordStart: String.Index = fullText.startIndex
        var currentWord = ""

        for (index, char) in fullText.enumerated() {
            let stringIndex = fullText.index(fullText.startIndex, offsetBy: index)

            if char.isLetter || char.isNumber {
                // Continue building the current word
                if currentWord.isEmpty {
                    currentWordStart = stringIndex
                }
                currentWord.append(char)
            } else {
                // End of word - process if we have accumulated a word
                if !currentWord.isEmpty {
                    let wordEndIndex = stringIndex
                    let wordRange = currentWordStart..<wordEndIndex

                    do {
                        // Use Vision API to get precise bounding box for this exact word range
                        if let wordBoundingBox = try recognizedText.boundingBox(for: wordRange) {
                            // Convert normalized coordinates to pixel coordinates
                            let normalizedRect = wordBoundingBox.boundingBox
                            let pixelRect = convertVisionRectToPixels(
                                normalizedRect: normalizedRect,
                                imageSize: imageSize
                            )

                            let wordBox = WordBoundingBox(
                                word: currentWord,
                                boundingBox: pixelRect,
                                range: wordRange
                            )

                            wordBoxes.append(wordBox)
                        }
                    } catch {
                        print("⚠️ Failed to get bounding box for word '\(currentWord)': \(error)")
                    }

                    // Reset for next word
                    currentWord = ""
                }
            }
        }

        // Handle final word if text doesn't end with separator
        if !currentWord.isEmpty {
            let wordRange = currentWordStart..<fullText.endIndex

            do {
                if let wordBoundingBox = try recognizedText.boundingBox(for: wordRange) {
                    let normalizedRect = wordBoundingBox.boundingBox
                    let pixelRect = convertVisionRectToPixels(
                        normalizedRect: normalizedRect,
                        imageSize: imageSize
                    )

                    let wordBox = WordBoundingBox(
                        word: currentWord,
                        boundingBox: pixelRect,
                        range: wordRange
                    )

                    wordBoxes.append(wordBox)
                }
            } catch {
                print("⚠️ Failed to get bounding box for final word '\(currentWord)': \(error)")
            }
        }

        return wordBoxes
    }

    private func convertVisionRectToPixels(normalizedRect: CGRect, imageSize: CGSize) -> CGRect {
        // Vision uses normalized coordinates with origin at bottom-left
        // Convert to pixel coordinates with origin at top-left (macOS standard)
        let x = normalizedRect.minX * imageSize.width
        let y = (1.0 - normalizedRect.maxY) * imageSize.height // Flip Y coordinate
        let width = normalizedRect.width * imageSize.width
        let height = normalizedRect.height * imageSize.height

        return CGRect(x: x, y: y, width: width, height: height)
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

    func generateScreenDescriptionWithData(from image: CGImage, textStrings: [String], textElements: [TextElementWithPosition] = [], windowStructure: WindowStructure, recentMouseEvents: [MouseEventData] = []) async -> String {
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

        // Add all detected text content with coordinates
        if !textElements.isEmpty {
            description += """

            DETECTED TEXT CONTENT WITH COORDINATES:
            ======================================

            """

            for textElement in textElements {
                let x = Int(textElement.boundingBox.minX)
                let y = Int(textElement.boundingBox.minY)
                let width = Int(textElement.boundingBox.width)
                let height = Int(textElement.boundingBox.height)

                description += "• [\(x),\(y),\(width)×\(height)] \(textElement.text)\n"

                // Add word-level coordinates if available
                if !textElement.wordBoundingBoxes.isEmpty {
                    for wordBox in textElement.wordBoundingBoxes {
                        let wx = Int(wordBox.boundingBox.minX)
                        let wy = Int(wordBox.boundingBox.minY)
                        let ww = Int(wordBox.boundingBox.width)
                        let wh = Int(wordBox.boundingBox.height)
                        description += "  - [\(wx),\(wy),\(ww)×\(wh)] '\(wordBox.word)'\n"
                    }
                }
            }
        } else if !textStrings.isEmpty {
            // Fallback to simple text list if no position data available
            description += """

            DETECTED TEXT CONTENT:
            =====================

            """

            for text in textStrings {
                description += "• \(text)\n"
            }
        }

        // Add mouse activity if available
        if !recentMouseEvents.isEmpty {
            description += """

            RECENT MOUSE ACTIVITY:
            =====================

            """

            let recentEvents = Array(recentMouseEvents.suffix(5))
            for event in recentEvents {
                let timeAgo = Int(Date().timeIntervalSince(event.timestamp))
                let position = "(\(Int(event.globalLocation.x)), \(Int(event.globalLocation.y)))"

                if let uiElement = event.associatedUIElement {
                    description += "• \(event.eventTypeName) on \(uiElement) at \(position) - \(timeAgo)s ago\n"
                } else if let text = event.associatedText {
                    description += "• \(event.eventTypeName) near '\(text.prefix(20))...' at \(position) - \(timeAgo)s ago\n"
                } else {
                    description += "• \(event.eventTypeName) at \(position) - \(timeAgo)s ago\n"
                }
            }
        }

        // Add UI tree hierarchy if available
        if !textElements.isEmpty {
            description += """

            UI ELEMENTS WITH PRECISE COORDINATES:
            ====================================

            """

            // Group by UI structure if we have the data
            for textElement in textElements {
                // Show hierarchical structure with coordinates
                description += "• \(textElement.coordinateDescription) \(textElement.displayText)\n"

                // Show word-level details if available
                if !textElement.wordBoundingBoxes.isEmpty && textElement.wordBoundingBoxes.count > 1 {
                    for wordBox in textElement.wordBoundingBoxes.prefix(5) { // Limit to avoid clutter
                        let wx = Int(wordBox.boundingBox.minX)
                        let wy = Int(wordBox.boundingBox.minY)
                        let ww = Int(wordBox.boundingBox.width)
                        let wh = Int(wordBox.boundingBox.height)
                        description += "  - [\(wx),\(wy),\(ww)×\(wh)] '\(wordBox.word)'\n"
                    }
                    if textElement.wordBoundingBoxes.count > 5 {
                        description += "  - ... and \(textElement.wordBoundingBoxes.count - 5) more words\n"
                    }
                }
            }
        }

        // Add layout analysis
        description += """

        LAYOUT ANALYSIS:
        ===============
        - Screen has \(textRectangles.count) distinct text regions
        - Text density: \(textRectangles.count > 0 ? String(format: "%.1f", Double(textStrings.count) / Double(textRectangles.count)) : "0") items per region
        - Active applications: \(windowStructure.applications.count)
        - Mouse events recorded: \(recentMouseEvents.count)

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

// MARK: - Supporting Types
// TextElementWithPosition and WordBoundingBox are now defined in ContextStreamManager.swift to resolve compilation issues

