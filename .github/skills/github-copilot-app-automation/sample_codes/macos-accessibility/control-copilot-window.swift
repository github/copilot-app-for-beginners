// Activate, enter full screen, or set capture zoom for one GitHub Copilot process.
//
// Usage:
//   control-copilot-window <pid> activate [timeout_seconds]
//   control-copilot-window <pid> fullscreen [timeout_seconds]
//   control-copilot-window <pid> capture-zoom [timeout_seconds]
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

func firstWindow(_ application: AXUIElement) -> AXUIElement? {
    guard let value = attribute(application, kAXWindowsAttribute as CFString),
          let windows = value as? [AXUIElement] else {
        return nil
    }
    return windows.first
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
    fail("Usage: control-copilot-window <pid> <activate|fullscreen|capture-zoom> [timeout_seconds]")
}

let mode = CommandLine.arguments[2]
guard mode == "activate" || mode == "fullscreen" || mode == "capture-zoom" else {
    fail("Mode must be 'activate', 'fullscreen', or 'capture-zoom'.")
}

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
    window = firstWindow(accessibilityApplication)
    if window != nil {
        break
    }
    Thread.sleep(forTimeInterval: 0.25)
}
guard let targetWindow = window else {
    fail("Process \(pid) did not expose an accessible window before the timeout.", code: 4)
}

if mode == "activate" {
    Thread.sleep(forTimeInterval: 1)
    print(pid)
    exit(0)
}

if mode == "capture-zoom" {
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

    sendShortcut(keyCode: 29) // Command+0 resets zoom.
    sendShortcut(keyCode: 24) // Command+= zooms in.
    sendShortcut(keyCode: 24)
    Thread.sleep(forTimeInterval: 1)
    print(pid)
    exit(0)
}

if !isFullScreen(targetWindow) {
    guard let buttonValue = attribute(targetWindow, "AXFullScreenButton" as CFString),
          CFGetTypeID(buttonValue) == AXUIElementGetTypeID() else {
        fail("Process \(pid) does not expose a full-screen button.", code: 5)
    }
    let fullScreenButton = unsafeBitCast(buttonValue, to: AXUIElement.self)
    let actionError = AXUIElementPerformAction(fullScreenButton, kAXPressAction as CFString)
    guard actionError == .success else {
        fail("Could not press the full-screen button for process \(pid): \(actionError.rawValue)", code: 5)
    }
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
