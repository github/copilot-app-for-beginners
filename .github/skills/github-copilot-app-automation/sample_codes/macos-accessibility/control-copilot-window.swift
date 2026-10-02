// Activate, frame, enter full screen, or set capture zoom for one GitHub Copilot
// process.
//
// Usage:
//   control-copilot-window <pid> activate [timeout_seconds]
//   control-copilot-window <pid> frame [timeout_seconds] [width_points]
//   control-copilot-window <pid> fullscreen [timeout_seconds]
//   control-copilot-window <pid> capture-zoom [timeout_seconds] [steps]
//
// "frame" is the capture layout. It leaves full screen when needed and sets the
// main window to an exact 16:9 size (1920x1080 points by default), centered in
// the visible area of the window's display. On a standard-resolution display,
// a 1920x1080-point window captures as a native 1080p image. A standard window
// keeps the window buttons inside the sidebar header, as learners see them.
// Full screen can draw the menu bar and title bar over the app content while
// the app is active, so it is not used for course captures.
// With COPILOT_CAPTURE_DISPLAY=builtin, "frame" puts the window on the built-in
// laptop display instead, so you can keep working on other displays.
//
// "capture-zoom" resets the web zoom (Command+0) and then zooms in (Command+=)
// four times by default, as the skill requires. That gives 175%. It waits
// for the app content to load first, and then measures a sidebar control to
// confirm that the zoom took effect. It retries, and it fails if it cannot
// confirm the zoom.
import AppKit
import ApplicationServices
import Foundation

func fail(_ message: String, code: Int32 = 1) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(code)
}

func attribute(_ element: AXUIElement, _ name: CFString) -> CFTypeRef? {
    var value: CFTypeRef?
    let error = AXUIElementCopyAttributeValue(element, name, &value)
    return error == .success ? value : nil
}

func string(_ element: AXUIElement, _ name: CFString) -> String {
    (attribute(element, name) as? String) ?? ""
}

func point(_ element: AXUIElement, _ name: String) -> CGPoint? {
    guard let value = attribute(element, name as CFString),
          CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
    var result = CGPoint.zero
    return AXValueGetValue(value as! AXValue, .cgPoint, &result) ? result : nil
}

func size(_ element: AXUIElement, _ name: String) -> CGSize? {
    guard let value = attribute(element, name as CFString),
          CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
    var result = CGSize.zero
    return AXValueGetValue(value as! AXValue, .cgSize, &result) ? result : nil
}

// The app can own small helper windows (for example, notices). Use the main
// window, or else the largest standard window, so the capture frame and zoom
// apply to the window that learners see.
func mainWindow(_ application: AXUIElement) -> AXUIElement? {
    if let value = attribute(application, kAXMainWindowAttribute as CFString),
       CFGetTypeID(value) == AXUIElementGetTypeID() {
        return unsafeBitCast(value, to: AXUIElement.self)
    }
    guard let windows = attribute(application, kAXWindowsAttribute as CFString) as? [AXUIElement],
          !windows.isEmpty else {
        return nil
    }
    let standard = windows.filter {
        string($0, kAXSubroleAttribute as CFString) == "AXStandardWindow"
    }
    return (standard.isEmpty ? windows : standard).max { first, second in
        let a = size(first, "AXSize") ?? .zero
        let b = size(second, "AXSize") ?? .zero
        return a.width * a.height < b.width * b.height
    }
}

func isFullScreen(_ window: AXUIElement) -> Bool {
    guard let value = attribute(window, "AXFullScreen" as CFString) else {
        return false
    }
    return (value as? NSNumber)?.boolValue ?? false
}

guard CommandLine.arguments.count >= 3,
      let rawPid = Int32(CommandLine.arguments[1]),
      rawPid > 0 else {
    fail("Usage: control-copilot-window <pid> <activate|frame|fullscreen|capture-zoom> [timeout_seconds] [width_points|steps]")
}

let mode = CommandLine.arguments[2]
guard ["activate", "frame", "fullscreen", "capture-zoom"].contains(mode) else {
    fail("Mode must be 'activate', 'frame', 'fullscreen', or 'capture-zoom'.")
}
let extraArgument = CommandLine.arguments.count > 4 ? CommandLine.arguments[4] : nil

let timeout = CommandLine.arguments.count > 3
    ? max(Double(CommandLine.arguments[3]) ?? 30, 1)
    : 30
let pid = pid_t(rawPid)

guard AXIsProcessTrusted() else {
    fail("Accessibility permission is required for the automation caller.", code: 2)
}
guard let runningApplication = NSRunningApplication(processIdentifier: pid) else {
    fail("Process \(pid) is not running.", code: 3)
}

let accessibilityApplication = AXUIElementCreateApplication(pid)
let deadline = Date().addingTimeInterval(timeout)

_ = runningApplication.activate(options: [.activateAllWindows])

var window: AXUIElement?
while Date() < deadline {
    window = mainWindow(accessibilityApplication)
    if window != nil {
        break
    }
    Thread.sleep(forTimeInterval: 0.25)
}
guard let targetWindow = window else {
    fail("Process \(pid) did not expose an accessible window before the timeout.", code: 4)
}

if mode == "activate" {
    _ = AXUIElementPerformAction(targetWindow, kAXRaiseAction as CFString)
    Thread.sleep(forTimeInterval: 1)
    print(pid)
    exit(0)
}

func pressFullScreenButton(_ window: AXUIElement) -> Bool {
    while Date() < deadline {
        if let buttonValue = attribute(window, "AXFullScreenButton" as CFString),
           CFGetTypeID(buttonValue) == AXUIElementGetTypeID() {
            let button = unsafeBitCast(buttonValue, to: AXUIElement.self)
            return AXUIElementPerformAction(button, kAXPressAction as CFString) == .success
        }
        // The button can appear after the window during app startup.
        Thread.sleep(forTimeInterval: 0.25)
    }
    return false
}

if mode == "frame" {
    var requestedWidth: Double = 1920
    if let extraArgument {
        guard let width = Double(extraArgument), width >= 640 else {
            fail("Frame width must be a number of points no smaller than 640.")
        }
        requestedWidth = width
    }
    if isFullScreen(targetWindow) {
        let setResult = AXUIElementSetAttributeValue(
            targetWindow, "AXFullScreen" as CFString, kCFBooleanFalse
        )
        if setResult != .success && !pressFullScreenButton(targetWindow) {
            fail("Could not leave full screen for process \(pid).", code: 5)
        }
        while Date() < deadline && isFullScreen(targetWindow) {
            Thread.sleep(forTimeInterval: 0.25)
        }
        guard !isFullScreen(targetWindow) else {
            fail("Process \(pid) did not leave full screen before the timeout.", code: 6)
        }
        // Wait for the Space transition to finish before moving the window.
        Thread.sleep(forTimeInterval: 1.5)
    }

    guard let primary = NSScreen.screens.first else {
        fail("No display is available.", code: 7)
    }
    let primaryHeight = primary.frame.maxY
    let origin = point(targetWindow, "AXPosition") ?? .zero
    let current = size(targetWindow, "AXSize") ?? CGSize(width: 800, height: 600)
    let center = CGPoint(x: origin.x + current.width / 2, y: primaryHeight - (origin.y + current.height / 2))
    let builtinScreen = NSScreen.screens.first {
        guard let id = $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            return false
        }
        return CGDisplayIsBuiltin(id) != 0
    }
    let wantsBuiltin = ProcessInfo.processInfo.environment["COPILOT_CAPTURE_DISPLAY"] == "builtin"
    if wantsBuiltin && builtinScreen == nil {
        fail("COPILOT_CAPTURE_DISPLAY=builtin is set, but no built-in display was found.", code: 7)
    }
    let screen = wantsBuiltin
        ? builtinScreen!
        : NSScreen.screens.first { $0.frame.contains(center) } ?? primary
    let visible = screen.visibleFrame
    // Convert the visible frame from Cocoa (bottom-left) to Accessibility
    // (top-left) coordinates.
    let area = CGRect(
        x: visible.minX,
        y: primaryHeight - visible.maxY,
        width: visible.width,
        height: visible.height
    )
    var width = (min(requestedWidth, area.width) / 16).rounded(.down) * 16
    if width * 9 / 16 > area.height {
        width = (area.height * 16 / 9 / 16).rounded(.down) * 16
    }
    if width < requestedWidth {
        FileHandle.standardError.write(Data(
            "Warning: the display is too small for a \(Int(requestedWidth))-point frame. Using \(Int(width)) points; captures are resized to 1920x1080.\n".utf8
        ))
    }
    let target = CGSize(width: width, height: width * 9 / 16)
    var targetOrigin = CGPoint(
        x: (area.minX + (area.width - target.width) / 2).rounded(),
        y: (area.minY + (area.height - target.height) / 2).rounded()
    )
    var targetSize = target

    while Date() < deadline {
        if let positionValue = AXValueCreate(.cgPoint, &targetOrigin),
           let sizeValue = AXValueCreate(.cgSize, &targetSize) {
            AXUIElementSetAttributeValue(targetWindow, kAXPositionAttribute as CFString, positionValue)
            AXUIElementSetAttributeValue(targetWindow, kAXSizeAttribute as CFString, sizeValue)
            AXUIElementSetAttributeValue(targetWindow, kAXPositionAttribute as CFString, positionValue)
        }
        Thread.sleep(forTimeInterval: 0.5)
        if let actual = size(targetWindow, "AXSize"),
           abs(actual.width - target.width) < 1,
           abs(actual.height - target.height) < 1 {
            _ = AXUIElementPerformAction(targetWindow, kAXRaiseAction as CFString)
            Thread.sleep(forTimeInterval: 1)
            print(pid)
            exit(0)
        }
    }
    fail("Process \(pid) did not accept a \(Int(target.width))x\(Int(target.height)) window frame.", code: 8)
}

if mode == "capture-zoom" {
    // Zoom levels that Command+= steps through, starting at 100%.
    let levels: [Double] = [100, 110, 125, 150, 175, 200, 250, 300]
    var steps = 4
    if let extraArgument {
        guard let explicitSteps = Int(extraArgument), (0..<levels.count).contains(explicitSteps) else {
            fail("Zoom steps must be a whole number from 0 to \(levels.count - 1).")
        }
        steps = explicitSteps
    }

    func sendShortcut(keyCode: CGKeyCode) {
        guard let keyDown = CGEvent(
            keyboardEventSource: nil,
            virtualKey: keyCode,
            keyDown: true
        ), let keyUp = CGEvent(
            keyboardEventSource: nil,
            virtualKey: keyCode,
            keyDown: false
        ) else {
            fail("Could not create a keyboard event.", code: 5)
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.postToPid(pid)
        keyUp.postToPid(pid)
        Thread.sleep(forTimeInterval: 0.5)
    }

    // A sidebar control with a fixed CSS height shows the current zoom.
    let referenceLabels = ["New", "Toggle sidebar, Command + B"]
    func referenceHeight() -> Double? {
        var pending = [targetWindow]
        while let element = pending.popLast() {
            let labels = [
                string(element, kAXTitleAttribute as CFString),
                string(element, kAXDescriptionAttribute as CFString)
            ]
            if labels.contains(where: referenceLabels.contains),
               let height = size(element, "AXSize")?.height, height > 0 {
                return Double(height)
            }
            if let children = attribute(element, kAXChildrenAttribute as CFString) as? [AXUIElement] {
                pending.append(contentsOf: children.reversed())
            }
        }
        return nil
    }

    // Wait until the web content is loaded. Zoom keys sent earlier are lost.
    while Date() < deadline && referenceHeight() == nil {
        Thread.sleep(forTimeInterval: 0.25)
    }
    guard referenceHeight() != nil else {
        fail("App content did not load before the timeout, so the zoom was not set.", code: 9)
    }

    let expected = levels[steps] / 100
    for attempt in 1...3 {
        _ = runningApplication.activate(options: [])
        sendShortcut(keyCode: 29) // Command+0 resets zoom.
        Thread.sleep(forTimeInterval: 0.8)
        guard let baseHeight = referenceHeight() else { continue }
        for _ in 0..<steps {
            sendShortcut(keyCode: 24) // Command+= zooms in.
        }
        Thread.sleep(forTimeInterval: 1)
        guard let zoomedHeight = referenceHeight() else { continue }
        let ratio = zoomedHeight / baseHeight
        if abs(ratio - expected) <= 0.08 {
            print(pid)
            exit(0)
        }
        FileHandle.standardError.write(Data(
            "Zoom attempt \(attempt) measured \(String(format: "%.2f", ratio))x; expected \(String(format: "%.2f", expected))x. Retrying.\n".utf8
        ))
        Thread.sleep(forTimeInterval: 1)
    }
    fail("Could not confirm a \(Int(levels[steps]))% zoom for process \(pid).", code: 10)
}

if !isFullScreen(targetWindow) && !pressFullScreenButton(targetWindow) {
    fail("Process \(pid) did not expose a usable full-screen button before the timeout.", code: 5)
}

while Date() < deadline {
    if isFullScreen(targetWindow) {
        Thread.sleep(forTimeInterval: 2)
        print(pid)
        exit(0)
    }
    Thread.sleep(forTimeInterval: 0.25)
}

fail("Process \(pid) did not enter full screen before the timeout.", code: 6)
