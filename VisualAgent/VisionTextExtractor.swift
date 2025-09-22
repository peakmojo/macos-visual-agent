import Foundation
@preconcurrency import Vision
import CoreGraphics
import AppKit

class VisionTextExtractor: ObservableObject {

    // MARK: - Text Recognition

    func extractText(from image: CGImage) async -> [TextElement] {
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    print("❌ Vision text recognition failed: \(error)")
                    continuation.resume(returning: [])
                    return
                }

                let textElements = self.processTextObservations(request.results as? [VNRecognizedTextObservation] ?? [], imageSize: CGSize(width: image.width, height: image.height))
                continuation.resume(returning: textElements)
            }

            // Configure for mixed Chinese/English text
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
            request.usesLanguageCorrection = true

            // Enable automatic language detection
            request.automaticallyDetectsLanguage = true

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

    private func processTextObservations(_ observations: [VNRecognizedTextObservation], imageSize: CGSize) -> [TextElement] {
        var textElements: [TextElement] = []

        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }

            // Convert Vision coordinates to screen coordinates
            let boundingBox = observation.boundingBox
            let rect = VNImageRectForNormalizedRect(boundingBox, Int(imageSize.width), Int(imageSize.height))

            let textElement = TextElement(
                text: topCandidate.string,
                confidence: topCandidate.confidence,
                boundingBox: rect,
                language: detectLanguage(topCandidate.string)
            )

            textElements.append(textElement)
        }

        return textElements
    }

    private func detectLanguage(_ text: String) -> TextLanguage {
        let chinesePattern = try! NSRegularExpression(pattern: "[\\u4e00-\\u9fff]", options: [])
        let chineseMatches = chinesePattern.numberOfMatches(in: text, options: [], range: NSRange(location: 0, length: text.count))

        if chineseMatches > 0 {
            return chineseMatches > text.count / 2 ? .chinese : .mixed
        } else {
            return .english
        }
    }
}

// MARK: - Supporting Types

struct TextElement: Identifiable {
    let id = UUID()
    let text: String
    let confidence: Float
    let boundingBox: CGRect
    let language: TextLanguage
    let timestamp: Date = Date()

    // Computed properties for UI analysis
    var isPossibleButton: Bool {
        return text.count < 30 &&
               (text.contains("按钮") || text.contains("Button") ||
                text.contains("确定") || text.contains("取消") ||
                text.contains("OK") || text.contains("Cancel") ||
                text.contains("Submit") || text.contains("提交"))
    }

    var isPossibleInputField: Bool {
        return text.contains("输入") || text.contains("Input") ||
               text.contains("搜索") || text.contains("Search") ||
               text.contains("用户名") || text.contains("Username") ||
               text.contains("密码") || text.contains("Password")
    }

    var isTitle: Bool {
        return boundingBox.height > 20 && text.count < 50 && confidence > 0.8
    }
}

enum TextLanguage {
    case chinese
    case english
    case mixed

    var displayName: String {
        switch self {
        case .chinese: return "中文"
        case .english: return "English"
        case .mixed: return "Mixed"
        }
    }
}