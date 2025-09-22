import Foundation
import CoreML
import CoreGraphics
import AppKit

@available(macOS 12.0, *)
class TestCoreMLIntegration {

    static func runTests() async {
        print("🧪 Starting CoreML Screen Description Tests...")

        // Test 1: Initialize CoreML Screen Describer
        await testInitialization()

        // Test 2: Test with sample screen data
        await testScreenAnalysis()

        print("✅ CoreML integration tests completed!")
    }

    private static func testInitialization() async {
        print("\n📋 Test 1: CoreML Screen Describer Initialization")

        let describer = CoreMLScreenDescriber()

        // Wait for model loading
        var attempts = 0
        while !describer.isModelLoaded && attempts < 10 {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            attempts += 1
        }

        if describer.isModelLoaded {
            print("✅ CoreML Screen Describer initialized successfully")
        } else {
            print("⚠️ CoreML Screen Describer took longer than expected to load (using fallback)")
        }
    }

    private static func testScreenAnalysis() async {
        print("\n📋 Test 2: Screen Analysis with Sample Data")

        let describer = CoreMLScreenDescriber()

        // Create a sample CGImage (1x1 pixel for testing)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil,
                                    width: 1920,
                                    height: 1080,
                                    bitsPerComponent: 8,
                                    bytesPerRow: 0,
                                    space: colorSpace,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            print("❌ Failed to create test CGContext")
            return
        }

        // Fill with a light blue color (simulating desktop)
        context.setFillColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1.0)
        context.fill(CGRect(x: 0, y: 0, width: 1920, height: 1080))

        guard let testImage = context.makeImage() else {
            print("❌ Failed to create test image")
            return
        }

        // Sample text elements (simulating extracted text)
        let sampleText = [
            "Visual Agent - Screen Monitor",
            "File Edit View Window Help",
            "Welcome to Visual Agent",
            "This is a sample text element",
            "Button: Save Document",
            "Menu: File > New Project"
        ]

        // Sample window structure
        let sampleWindowStructure = WindowStructure(
            displays: [DisplayInfo(id: 1, width: 1920, height: 1080)],
            applications: [
                ApplicationInfo(bundleIdentifier: "com.apple.finder", applicationName: "Finder", processIdentifier: 123),
                ApplicationInfo(bundleIdentifier: "com.visualAgent.app", applicationName: "Visual Agent", processIdentifier: 456)
            ],
            windows: [
                WindowInfo(windowID: 1, title: "Visual Agent", frame: CGRect(x: 100, y: 100, width: 800, height: 600), isOnScreen: true, owningApplicationBundleID: "com.visualAgent.app"),
                WindowInfo(windowID: 2, title: "Finder", frame: CGRect(x: 200, y: 200, width: 600, height: 400), isOnScreen: true, owningApplicationBundleID: "com.apple.finder")
            ]
        )

        // Sample UI elements
        let sampleUIElements: [UIElement] = [
            createSampleUIElement(type: .button, title: "Save", frame: CGRect(x: 100, y: 50, width: 60, height: 30)),
            createSampleUIElement(type: .textInput, title: "Document Name", frame: CGRect(x: 200, y: 50, width: 200, height: 25)),
            createSampleUIElement(type: .menu, title: "File Menu", frame: CGRect(x: 50, y: 20, width: 40, height: 20)),
            createSampleUIElement(type: .button, title: "Cancel", frame: CGRect(x: 170, y: 50, width: 60, height: 30))
        ]

        print("📊 Generating enhanced screen description...")

        let startTime = CFAbsoluteTimeGetCurrent()

        // Create a sample base description (what the Vision text extractor would provide)
        let baseDescription = """
        SCREEN CONTENT ANALYSIS
        ===================================

        Display: 1920 × 1080 pixels
        Time: \(Date().formatted(.dateTime.hour().minute().second()))
        Text Elements: \(sampleText.count)
        UI Elements: \(sampleUIElements.count)

        TEXT CONTENT WITH COORDINATES:
        \(sampleText.enumerated().map { "• [\($0.offset * 100),\($0.offset * 25),200×30] \($0.element)" }.joined(separator: "\n"))
        """

        let description = await describer.enhanceScreenDescription(
            baseDescription: baseDescription,
            from: testImage,
            textElements: sampleText,
            windowInfo: sampleWindowStructure,
            uiElements: sampleUIElements
        )

        let processingTime = CFAbsoluteTimeGetCurrent() - startTime

        print("⏱️ Processing time: \(String(format: "%.3f", processingTime)) seconds")
        print("\n📝 Generated Description:\n")
        print(description)
        print("\n" + String(repeating: "=", count: 50))

        if description.contains("🧠 AI CONTEXTUAL INSIGHTS") {
            print("✅ CoreML enhanced description generated successfully")
        } else {
            print("⚠️ Fallback description used (CoreML model may not be available)")
        }

        // Test different screen types
        await testScreenTypeDetection(describer: describer, testImage: testImage)
    }

    private static func testScreenTypeDetection(describer: CoreMLScreenDescriber, testImage: CGImage) async {
        print("\n📋 Test 3: Screen Type Detection")

        // Test development screen
        let codeText = [
            "function processData() {",
            "  const result = data.map(item => {",
            "    return item.value * 2;",
            "  });",
            "  console.log(result);",
            "}",
            "import React from 'react';",
            "class Component extends React.Component {"
        ]

        let devBaseDescription = """
        SCREEN CONTENT ANALYSIS
        ===================================

        TEXT CONTENT:
        \(codeText.joined(separator: "\n"))
        """

        let devDescription = await describer.enhanceScreenDescription(
            baseDescription: devBaseDescription,
            from: testImage,
            textElements: codeText,
            windowInfo: nil,
            uiElements: []
        )

        if devDescription.contains("Development Environment") {
            print("✅ Development screen type detected correctly")
        } else {
            print("⚠️ Development screen type not detected")
        }

        // Test web browsing screen
        let webText = [
            "Search Google or type a URL",
            "https://www.example.com",
            "Welcome to Example.com",
            "Click here to learn more",
            "www.github.com",
            "Sign in to your account"
        ]

        let webBaseDescription = """
        SCREEN CONTENT ANALYSIS
        ===================================

        TEXT CONTENT:
        \(webText.joined(separator: "\n"))
        """

        let webDescription = await describer.enhanceScreenDescription(
            baseDescription: webBaseDescription,
            from: testImage,
            textElements: webText,
            windowInfo: nil,
            uiElements: []
        )

        if webDescription.contains("Web Browser") {
            print("✅ Web browser screen type detected correctly")
        } else {
            print("⚠️ Web browser screen type not detected")
        }
    }

    private static func createSampleUIElement(type: UIElementType, title: String, frame: CGRect) -> UIElement {
        return UIElement(
            role: "AX\(type.rawValue)",
            title: title,
            value: nil,
            description: "Sample \(type.rawValue) element",
            help: nil,
            allText: title,
            frame: frame,
            enabled: true,
            depth: 1,
            elementType: type,
            path: "Root > Window > \(title)"
        )
    }
}

// Note: displayText property already exists in UIElement