import Foundation
@preconcurrency import ApplicationServices
import AppKit

// Define all accessibility constants to ensure they're properly typed as CFString
private let kAXApplicationRole = "AXApplication" as CFString
private let kAXWindowRole = "AXWindow" as CFString
private let kAXButtonRole = "AXButton" as CFString

class AccessibilityAnalyzer: ObservableObject, @unchecked Sendable {

    // MARK: - Permission Management

    func checkAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - UI Element Extraction

    func extractUIElements(from bundleID: String) async -> [UIElement] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    DispatchQueue.main.async {
                        continuation.resume(returning: [])
                    }
                    return
                }
                let elements = self.analyzeApplication(bundleID: bundleID)
                DispatchQueue.main.async {
                    continuation.resume(returning: elements)
                }
            }
        }
    }

    // MARK: - Complete UI Tree Extraction (Enhanced Method)

    func extractCompleteUITree(from bundleID: String) async -> [UIElement] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    DispatchQueue.main.async {
                        continuation.resume(returning: [])
                    }
                    return
                }
                let elements = self.analyzeApplicationComplete(bundleID: bundleID)
                DispatchQueue.main.async {
                    continuation.resume(returning: elements)
                }
            }
        }
    }

    private func analyzeApplication(bundleID: String) -> [UIElement] {
        guard checkAccessibilityPermission() else {
            print("❌ Accessibility permission not granted")
            return []
        }

        guard let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first,
              runningApp.processIdentifier > 0 else {
            print("❌ Application not found: \(bundleID)")
            return []
        }

        let appElement = AXUIElementCreateApplication(runningApp.processIdentifier)
        var uiElements: [UIElement] = []

        // Get all windows
        if let windows = getElementAttribute(appElement, kAXWindowsAttribute as CFString) as? [AXUIElement] {
            for window in windows {
                let windowElements = analyzeElement(window, depth: 0, maxDepth: 5)
                uiElements.append(contentsOf: windowElements)
            }
        }

        return uiElements
    }

    private func analyzeElement(_ element: AXUIElement, depth: Int, maxDepth: Int) -> [UIElement] {
        guard depth < maxDepth else { return [] }

        var elements: [UIElement] = []

        // Get basic attributes
        let role = getElementAttribute(element, kAXRoleAttribute as CFString) as? String ?? ""
        let title = getElementAttribute(element, kAXTitleAttribute as CFString) as? String
        let value = getElementAttribute(element, kAXValueAttribute as CFString) as? String
        let enabled = getElementAttribute(element, kAXEnabledAttribute as CFString) as? Bool ?? false
        let frame = getElementFrame(element)

        // Filter for actionable elements
        if isActionableElement(role: role) {
            let uiElement = UIElement(
                role: role,
                title: title,
                value: value,
                frame: frame,
                enabled: enabled,
                depth: depth,
                elementType: classifyElementType(role: role, title: title)
            )
            elements.append(uiElement)
        }

        // Recursively analyze children
        if let children = getElementAttribute(element, kAXChildrenAttribute as CFString) as? [AXUIElement] {
            for child in children {
                let childElements = analyzeElement(child, depth: depth + 1, maxDepth: maxDepth)
                elements.append(contentsOf: childElements)
            }
        }

        return elements
    }

    // MARK: - Enhanced Complete Analysis

    private func analyzeApplicationComplete(bundleID: String) -> [UIElement] {
        guard checkAccessibilityPermission() else {
            print("❌ Accessibility permission not granted")
            return []
        }

        guard let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first,
              runningApp.processIdentifier > 0 else {
            print("❌ Application not found: \(bundleID)")
            return []
        }

        let appElement = AXUIElementCreateApplication(runningApp.processIdentifier)
        var uiElements: [UIElement] = []

        print("🔍 Starting complete UI tree analysis for \(bundleID)")

        // Get all windows with enhanced analysis
        if let windows = getElementAttribute(appElement, kAXWindowsAttribute as CFString) as? [AXUIElement] {
            print("📱 Found \(windows.count) windows")
            for (index, window) in windows.enumerated() {
                print("🪟 Analyzing window \(index + 1)")
                let windowElements = analyzeElementComplete(window, depth: 0, maxDepth: 10, path: "Window[\(index)]")
                uiElements.append(contentsOf: windowElements)
            }
        }

        print("✅ Complete analysis found \(uiElements.count) UI elements")
        return uiElements
    }

    private func analyzeElementComplete(_ element: AXUIElement, depth: Int, maxDepth: Int, path: String) -> [UIElement] {
        guard depth < maxDepth else { return [] }

        var elements: [UIElement] = []

        // Get comprehensive attributes
        let role = getElementAttribute(element, kAXRoleAttribute as CFString) as? String ?? ""
        let title = getElementAttribute(element, kAXTitleAttribute as CFString) as? String
        let value = getElementAttribute(element, kAXValueAttribute as CFString) as? String
        let description = getElementAttribute(element, "AXDescription" as CFString) as? String
        let help = getElementAttribute(element, "AXHelp" as CFString) as? String
        let enabled = getElementAttribute(element, kAXEnabledAttribute as CFString) as? Bool ?? false
        let frame = getElementFrame(element)

        // Extract all possible text content
        let allTextContent = extractAllTextContent(from: element)

        // Create comprehensive element data
        if shouldIncludeElement(role: role, title: title, value: value, description: description, allText: allTextContent) {
            let uiElement = UIElement(
                role: role,
                title: title,
                value: value,
                description: description,
                help: help,
                allText: allTextContent,
                frame: frame,
                enabled: enabled,
                depth: depth,
                elementType: classifyElementType(role: role, title: title),
                path: path
            )
            elements.append(uiElement)

            if !allTextContent.isEmpty {
                print("📝 [\(path)] \(role): \"\(allTextContent)\" at (\(Int(frame.minX)),\(Int(frame.minY)))")
            }
        }

        // Recursively analyze all children
        if let children = getElementAttribute(element, kAXChildrenAttribute as CFString) as? [AXUIElement] {
            for (index, child) in children.enumerated() {
                let childPath = "\(path)/\(role)[\(index)]"
                let childElements = analyzeElementComplete(child, depth: depth + 1, maxDepth: maxDepth, path: childPath)
                elements.append(contentsOf: childElements)
            }
        }

        return elements
    }

    private func extractAllTextContent(from element: AXUIElement) -> String {
        var textParts: [String] = []

        // Try various text-related attributes
        let textAttributes: [CFString] = [
            kAXValueAttribute as CFString,
            kAXTitleAttribute as CFString,
            "AXDescription" as CFString,
            "AXHelp" as CFString,
            "AXSelectedText" as CFString,
            "AXPlaceholderValue" as CFString
        ]

        for attribute in textAttributes {
            if let text = getElementAttribute(element, attribute) as? String,
               !text.isEmpty,
               !textParts.contains(text) {
                textParts.append(text)
            }
        }

        return textParts.joined(separator: " | ")
    }

    private func shouldIncludeElement(role: String, title: String?, value: String?, description: String?, allText: String) -> Bool {
        // Include if it has any text content or is a structural element
        if !allText.isEmpty {
            return true
        }

        // Include important structural elements even without text
        let structuralRoles = [
            "AXWindow", "AXApplication", "AXMenuBar", "AXMenu", "AXMenuItem",
            "AXToolbar", "AXTabGroup", "AXTab", "AXGroup", "AXScrollArea",
            "AXTable", "AXOutline", "AXList", "AXRow", "AXCell"
        ]

        return structuralRoles.contains(role) || isActionableElement(role: role)
    }

    private func getElementAttribute(_ element: AXUIElement, _ attribute: CFString) -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        return result == .success ? value : nil
    }

    private func getElementFrame(_ element: AXUIElement) -> CGRect {
        guard let positionValue = getElementAttribute(element, kAXPositionAttribute as CFString),
              let sizeValue = getElementAttribute(element, kAXSizeAttribute as CFString) else {
            return .zero
        }

        var position = CGPoint.zero
        var size = CGSize.zero

        AXValueGetValue(positionValue as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)

        return CGRect(origin: position, size: size)
    }

    private func isActionableElement(role: String) -> Bool {
        let actionableRoles = [
            "AXButton",
            "AXCheckBox",
            "AXComboBox",
            "AXTextField",
            "AXTextArea",
            "AXPopUpButton",
            "AXMenuItem",
            "AXMenuButton",
            "AXTab",
            "AXRadioButton",
            "AXSlider",
            "AXStepper",
            "AXTable",
            "AXOutline",
            "AXList",
            "AXLink"
        ]

        return actionableRoles.contains(role)
    }

    private func classifyElementType(role: String, title: String?) -> UIElementType {
        switch role {
        case "AXButton":
            return .button
        case "AXTextField", "AXTextArea":
            return .textInput
        case "AXCheckBox":
            return .checkbox
        case "AXComboBox", "AXPopUpButton":
            return .dropdown
        case "AXMenuItem", "AXMenuButton":
            return .menu
        case "AXTab":
            return .tab
        case "AXRadioButton":
            return .radioButton
        case "AXSlider":
            return .slider
        case "AXTable", "AXOutline", "AXList":
            return .list
        case "AXLink":
            return .link
        default:
            return .other
        }
    }
}

// MARK: - Supporting Types

struct UIElement: Identifiable {
    let id = UUID()
    let role: String
    let title: String?
    let value: String?
    let description: String?
    let help: String?
    let allText: String
    let frame: CGRect
    let enabled: Bool
    let depth: Int
    let elementType: UIElementType
    let path: String
    let timestamp: Date = Date()

    // Legacy initializer for backwards compatibility
    init(role: String, title: String?, value: String?, frame: CGRect, enabled: Bool, depth: Int, elementType: UIElementType) {
        self.role = role
        self.title = title
        self.value = value
        self.description = nil
        self.help = nil
        self.allText = title ?? value ?? ""
        self.frame = frame
        self.enabled = enabled
        self.depth = depth
        self.elementType = elementType
        self.path = "Legacy"
    }

    // Enhanced initializer
    init(role: String, title: String?, value: String?, description: String?, help: String?, allText: String, frame: CGRect, enabled: Bool, depth: Int, elementType: UIElementType, path: String) {
        self.role = role
        self.title = title
        self.value = value
        self.description = description
        self.help = help
        self.allText = allText
        self.frame = frame
        self.enabled = enabled
        self.depth = depth
        self.elementType = elementType
        self.path = path
    }

    var displayText: String {
        if !allText.isEmpty {
            return allText
        }
        return title ?? value ?? role
    }

    var isVisible: Bool {
        return frame.width > 1 && frame.height > 1
    }

    var area: CGFloat {
        return frame.width * frame.height
    }

    var coordinateDescription: String {
        return "[\(Int(frame.minX)),\(Int(frame.minY)),\(Int(frame.width))×\(Int(frame.height))]"
    }
}

enum UIElementType: String, CaseIterable {
    case button = "Button"
    case textInput = "Text Input"
    case checkbox = "Checkbox"
    case dropdown = "Dropdown"
    case menu = "Menu"
    case tab = "Tab"
    case radioButton = "Radio Button"
    case slider = "Slider"
    case list = "List"
    case link = "Link"
    case other = "Other"

    var icon: String {
        switch self {
        case .button: return "rectangle.roundedtop"
        case .textInput: return "textformat"
        case .checkbox: return "checkmark.square"
        case .dropdown: return "chevron.down.square"
        case .menu: return "line.horizontal.3"
        case .tab: return "rectangle.3.offgrid"
        case .radioButton: return "circle"
        case .slider: return "slider.horizontal.3"
        case .list: return "list.bullet"
        case .link: return "link"
        case .other: return "questionmark.square"
        }
    }
}