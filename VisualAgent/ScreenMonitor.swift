import Foundation
import CoreGraphics
import AppKit
import Combine

class ScreenMonitor: ObservableObject {
    @Published var isMonitoring = false
    @Published var lastScreenshot: NSImage?
    @Published var mousePosition: CGPoint = .zero
    @Published var keystrokes: [String] = []
    
    private var screenshotTimer: Timer?
    private var mouseTimer: Timer?
    private var eventTap: CFMachPort?
    private let maxKeystrokeHistory = 100
    
    init() {
        requestPermissions()
    }
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        startScreenshotCapture()
        startMouseTracking()
        startKeystrokeCapture()
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        screenshotTimer?.invalidate()
        mouseTimer?.invalidate()
        
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
    }
    
    private func requestPermissions() {
        // Request screen recording permission
        let _ = CGRequestScreenCaptureAccess()
        
        // Request accessibility permission for keystroke monitoring
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        let _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    private func startScreenshotCapture() {
        screenshotTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.captureScreenshot()
        }
    }
    
    private func startMouseTracking() {
        mouseTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateMousePosition()
        }
    }
    
    private func startKeystrokeCapture() {
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                let monitor = Unmanaged<ScreenMonitor>.fromOpaque(refcon!).takeUnretainedValue()
                monitor.handleKeyEvent(event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        )
        
        if let eventTap = eventTap {
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }
    }
    
    private func captureScreenshot() {
        guard let display = CGMainDisplayID() as CGDirectDisplayID? else { return }
        
        let screenRect = CGDisplayBounds(display)
        guard let image = CGDisplayCreateImage(display) else { return }
        
        let nsImage = NSImage(cgImage: image, size: screenRect.size)
        
        DispatchQueue.main.async {
            self.lastScreenshot = nsImage
        }
    }
    
    private func updateMousePosition() {
        let location = NSEvent.mouseLocation
        DispatchQueue.main.async {
            self.mousePosition = location
        }
    }
    
    private func handleKeyEvent(event: CGEvent) {
        guard let keyCode = event.getIntegerValueField(.keyboardEventKeycode) as Int64? else { return }
        
        let key = keyCodeToString(Int(keyCode))
        
        DispatchQueue.main.async {
            self.keystrokes.append(key)
            if self.keystrokes.count > self.maxKeystrokeHistory {
                self.keystrokes.removeFirst()
            }
        }
    }
    
    private func keyCodeToString(_ keyCode: Int) -> String {
        let keyMap: [Int: String] = [
            0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z", 7: "x", 8: "c", 9: "v",
            11: "b", 12: "q", 13: "w", 14: "e", 15: "r", 16: "y", 17: "t", 18: "1", 19: "2",
            20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8",
            29: "0", 30: "]", 31: "o", 32: "u", 33: "[", 34: "i", 35: "p", 37: "l", 38: "j",
            39: "'", 40: "k", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "n", 46: "m", 47: ".",
            49: "space", 51: "delete", 53: "escape", 55: "cmd", 56: "shift", 57: "caps",
            58: "option", 59: "ctrl", 60: "shift", 61: "option", 62: "ctrl", 63: "fn",
            96: "f5", 97: "f6", 98: "f7", 99: "f3", 100: "f8", 101: "f9", 103: "f11",
            109: "f10", 111: "f12", 113: "f13", 114: "help", 115: "home", 116: "pageup",
            117: "delete", 118: "f4", 119: "end", 120: "f2", 121: "pagedown", 122: "f1",
            123: "left", 124: "right", 125: "down", 126: "up"
        ]
        
        return keyMap[keyCode] ?? "unknown(\(keyCode))"
    }
    
    deinit {
        stopMonitoring()
    }
}