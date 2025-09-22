import Foundation
@preconcurrency import ApplicationServices
import AppKit

class AccessibilityAnalyzer: ObservableObject {

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
        if let windows = getElementAttribute(appElement, "AXWindows" as CFString) as? [AXUIElement] {
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
        let role = getElementAttribute(element, "AXRole" as CFString) as? String ?? ""
        let title = getElementAttribute(element, "AXTitle" as CFString) as? String
        let value = getElementAttribute(element, "AXValue" as CFString) as? String
        let enabled = getElementAttribute(element, "AXEnabled" as CFString) as? Bool ?? false
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
        if let children = getElementAttribute(element, "AXChildren" as CFString) as? [AXUIElement] {
            for child in children {
                let childElements = analyzeElement(child, depth: depth + 1, maxDepth: maxDepth)
                elements.append(contentsOf: childElements)
            }
        }

        return elements
    }

    private func getElementAttribute(_ element: AXUIElement, _ attribute: CFString) -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        return result == .success ? value : nil
    }

    private func getElementFrame(_ element: AXUIElement) -> CGRect {
        guard let positionValue = getElementAttribute(element, "AXPosition" as CFString),
              let sizeValue = getElementAttribute(element, "AXSize" as CFString) else {
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
    let frame: CGRect
    let enabled: Bool
    let depth: Int
    let elementType: UIElementType
    let timestamp: Date = Date()

    var displayText: String {
        return title ?? value ?? role
    }

    var isVisible: Bool {
        return frame.width > 1 && frame.height > 1
    }

    var area: CGFloat {
        return frame.width * frame.height
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