// Enable and verify Streamer Mode in one GitHub Copilot process.
//
// Usage:
//   ensure-streamer-mode <pid> [timeout_seconds]
import AppKit
import ApplicationServices
import Foundation

func fail(_ message: String, code: Int32 = 1) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(code)
}

func attribute(_ element: AXUIElement, _ name: CFString) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, name, &value) == .success ? value : nil
}

func stringAttribute(_ element: AXUIElement, _ name: CFString) -> String {
    (attribute(element, name) as? String) ?? ""
}

func allElements(in root: AXUIElement) -> [AXUIElement] {
    var result: [AXUIElement] = []
    var pending = [root]
    while let element = pending.popLast() {
        result.append(element)
        if let children = attribute(element, kAXChildrenAttribute as CFString) as? [AXUIElement] {
            pending.append(contentsOf: children.reversed())
        }
    }
    return result
}

func normalized(_ value: String) -> String {
    value.lowercased().filter(\.isLetter)
}

func describesStreamerMode(_ element: AXUIElement) -> Bool {
    let values = [
        stringAttribute(element, kAXTitleAttribute as CFString),
        stringAttribute(element, kAXDescriptionAttribute as CFString),
        stringAttribute(element, kAXValueAttribute as CFString)
    ]
    return values.contains { normalized($0).contains("streamermode") }
}

func isToggle(_ element: AXUIElement) -> Bool {
    let role = stringAttribute(element, kAXRoleAttribute as CFString)
    return role == kAXCheckBoxRole as String || role == "AXSwitch"
}

func isEnabled(_ element: AXUIElement) -> Bool {
    guard let value = attribute(element, kAXValueAttribute as CFString) else {
        return false
    }
    if let number = value as? NSNumber {
        return number.boolValue
    }
    let text = String(describing: value).lowercased()
    return text == "1" || text == "true" || text == "on"
}

func press(_ element: AXUIElement, label: String) {
    let error = AXUIElementPerformAction(element, kAXPressAction as CFString)
    guard error == .success else {
        fail("Could not press \(label): \(error.rawValue)", code: 5)
    }
}

func findElement(
    in root: AXUIElement,
    target: String,
    role: String? = nil
) -> AXUIElement? {
    let expected = normalized(target)
    return allElements(in: root).first { element in
        let values = [
            stringAttribute(element, kAXTitleAttribute as CFString),
            stringAttribute(element, kAXDescriptionAttribute as CFString),
            stringAttribute(element, kAXValueAttribute as CFString)
        ]
        let elementRole = stringAttribute(element, kAXRoleAttribute as CFString)
        return values.contains { normalized($0).contains(expected) }
            && (role == nil || elementRole == role)
    }
}

func findStreamerToggle(in root: AXUIElement) -> AXUIElement? {
    let elements = allElements(in: root)
    if let direct = elements.first(where: { isToggle($0) && describesStreamerMode($0) }) {
        return direct
    }
    guard let labelIndex = elements.firstIndex(where: describesStreamerMode) else {
        return nil
    }
    let lowerBound = max(0, labelIndex - 8)
    let upperBound = min(elements.count, labelIndex + 9)
    return elements[lowerBound..<upperBound].first(where: isToggle)
}

guard CommandLine.arguments.count >= 2,
      let rawPid = Int32(CommandLine.arguments[1]),
      rawPid > 0 else {
    fail("Usage: ensure-streamer-mode <pid> [timeout_seconds]")
}

let timeout = CommandLine.arguments.count > 2
    ? max(Double(CommandLine.arguments[2]) ?? 30, 1)
    : 30
let deadline = Date().addingTimeInterval(timeout)
let pid = pid_t(rawPid)

guard AXIsProcessTrusted() else {
    fail("Accessibility permission is required for the automation caller.", code: 2)
}
guard let runningApplication = NSRunningApplication(processIdentifier: pid) else {
    fail("Process \(pid) is not running.", code: 3)
}

let application = AXUIElementCreateApplication(pid)
_ = runningApplication.activate(options: [.activateAllWindows])

guard let settings = findElement(
    in: application,
    target: "Settings, Command + Comma",
    role: kAXButtonRole as String
) else {
    fail("The Settings button was not found.", code: 4)
}
press(settings, label: "Settings")

var general: AXUIElement?
while Date() < deadline {
    general = findElement(in: application, target: "General", role: kAXButtonRole as String)
    if general != nil {
        break
    }
    Thread.sleep(forTimeInterval: 0.25)
}
guard let generalButton = general else {
    fail("The General settings category did not appear.", code: 4)
}
press(generalButton, label: "General")

var toggle: AXUIElement?
while Date() < deadline {
    toggle = findStreamerToggle(in: application)
    if toggle != nil {
        break
    }
    Thread.sleep(forTimeInterval: 0.25)
}
guard let streamerToggle = toggle else {
    fail("Streamer Mode was not found in General settings.", code: 4)
}

_ = AXUIElementPerformAction(streamerToggle, "AXScrollToVisible" as CFString)
if !isEnabled(streamerToggle) {
    press(streamerToggle, label: "Streamer Mode")
}

var verified = false
while Date() < deadline {
    if let currentToggle = findStreamerToggle(in: application), isEnabled(currentToggle) {
        verified = true
        break
    }
    Thread.sleep(forTimeInterval: 0.25)
}
guard verified else {
    fail("Streamer Mode could not be verified as enabled.", code: 6)
}

if let close = findElement(in: application, target: "Close dialog", role: kAXButtonRole as String) {
    press(close, label: "Close dialog")
}

Thread.sleep(forTimeInterval: 1)
print("streamer-mode=on")
