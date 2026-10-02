// Prepare transient UI state in an exact GitHub Copilot process before capture.
//
// Some course screenshots need a hover state (for example, the + that appears
// only when the pointer is over the Chats row) or text in a field. Named
// Accessibility actions cannot create a hover, so this tool moves the pointer
// to the center of a named control. It targets controls by label, never by
// fixed pixel coordinates.
//
// Usage:
//   prepare-copilot-state <pid> hover <label> [role]
//   prepare-copilot-state <pid> park [keep-focus]
//   prepare-copilot-state <pid> set-value <label> <text> [role]
//   prepare-copilot-state <pid> show-menu <label> [role]
//   prepare-copilot-state <pid> key <escape|return|tab|down|up> [count]
//   prepare-copilot-state <pid> highlight-menu-item <label>
//   prepare-copilot-state <pid> dismiss-banners
//   prepare-copilot-state <pid> focus <label> [role]
//
// "park" moves the pointer to the bottom-right corner of the window content so
// no hover effects or tooltips appear in the capture. It also moves keyboard
// focus to the page, which removes a focus ring left on a button after a menu
// closes. Add "keep-focus" to leave focus unchanged (for example, when the
// capture must show a focused text field). "set-value" never sends
// Return, so it does not submit a prompt.
//
// Web menus in the app do not follow synthetic pointer moves. To show a menu
// item as selected, "highlight-menu-item" presses Down until that item is the
// active descendant, then checks the result. It never presses Return.
//
// "focus" gives keyboard focus to a control without pressing it. Use it to show
// a control that appears only on hover (for example, the + on the Chats row)
// while a menu elsewhere stays open: a focused control also shows its focus
// ring and tooltip, which helps a reader find it in the screenshot.
//
// "dismiss-banners" removes transient promotions and notices that would
// otherwise appear in a capture. It presses only buttons on a safe allowlist
// ("Close banner", "Later", "Not now", "Dismiss"). It never presses
// "Restart now", "Switch to Auto", or any other action button.
import AppKit
import ApplicationServices
import Foundation

func fail(_ message: String, code: Int32 = 1) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(code)
}

func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
}

func string(_ element: AXUIElement, _ name: String) -> String {
    (attribute(element, name) as? String) ?? ""
}

func rect(_ element: AXUIElement) -> CGRect? {
    guard let positionValue = attribute(element, kAXPositionAttribute),
          let sizeValue = attribute(element, kAXSizeAttribute),
          CFGetTypeID(positionValue) == AXValueGetTypeID(),
          CFGetTypeID(sizeValue) == AXValueGetTypeID() else {
        return nil
    }
    var origin = CGPoint.zero
    var size = CGSize.zero
    AXValueGetValue(positionValue as! AXValue, .cgPoint, &origin)
    AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
    return CGRect(origin: origin, size: size)
}

func find(_ root: AXUIElement, label: String, role: String?) -> AXUIElement? {
    var pending = [root]
    while let element = pending.popLast() {
        let values = [
            string(element, kAXTitleAttribute),
            string(element, kAXDescriptionAttribute),
            string(element, kAXValueAttribute)
        ]
        if values.contains(label), role == nil || string(element, kAXRoleAttribute) == role {
            return element
        }
        if let children = attribute(element, kAXChildrenAttribute) as? [AXUIElement] {
            pending.append(contentsOf: children.reversed())
        }
    }
    return nil
}

// Use the main window, or else the largest standard window. The app can own
// small helper windows that must not be used for coordinates.
func mainWindow(_ application: AXUIElement) -> AXUIElement? {
    if let value = attribute(application, kAXMainWindowAttribute),
       CFGetTypeID(value) == AXUIElementGetTypeID() {
        return unsafeBitCast(value, to: AXUIElement.self)
    }
    guard let windows = attribute(application, kAXWindowsAttribute) as? [AXUIElement] else {
        return nil
    }
    let standard = windows.filter { string($0, kAXSubroleAttribute) == "AXStandardWindow" }
    return (standard.isEmpty ? windows : standard).max { first, second in
        let a = rect(first)?.size ?? .zero
        let b = rect(second)?.size ?? .zero
        return a.width * a.height < b.width * b.height
    }
}

func movePointer(to point: CGPoint) {
    CGWarpMouseCursorPosition(point)
    if let event = CGEvent(
        mouseEventSource: nil,
        mouseType: .mouseMoved,
        mouseCursorPosition: point,
        mouseButton: .left
    ) {
        event.post(tap: .cghidEventTap)
    }
}

let arguments = CommandLine.arguments
guard arguments.count >= 3, let rawPid = Int32(arguments[1]), rawPid > 0 else {
    fail("Usage: prepare-copilot-state <pid> <hover|park|set-value|show-menu|key> ...")
}
guard AXIsProcessTrusted() else {
    fail("Accessibility permission is required for the automation caller.", code: 2)
}
let pid = pid_t(rawPid)
guard let running = NSRunningApplication(processIdentifier: pid) else {
    fail("Process \(pid) is not running.", code: 3)
}
let application = AXUIElementCreateApplication(pid)
let mode = arguments[2]
_ = running.activate(options: [])
Thread.sleep(forTimeInterval: 0.3)

switch mode {
case "hover":
    guard arguments.count >= 4 else { fail("hover needs a label.") }
    let role = arguments.count > 4 ? arguments[4] : nil
    guard let element = find(application, label: arguments[3], role: role),
          let frame = rect(element) else {
        fail("No matching element was found: \(arguments[3])", code: 4)
    }
    // Enter from slightly outside the control so web hover handlers fire.
    movePointer(to: CGPoint(x: frame.midX - frame.width, y: frame.midY))
    Thread.sleep(forTimeInterval: 0.2)
    movePointer(to: CGPoint(x: frame.midX, y: frame.midY))
    Thread.sleep(forTimeInterval: 0.6)
    print("hover \(arguments[3])")

case "park":
    guard let window = mainWindow(application),
          let frame = rect(window) else {
        fail("Process \(pid) has no accessible window.", code: 3)
    }
    movePointer(to: CGPoint(x: frame.maxX - 6, y: frame.maxY - 6))
    if !(arguments.count > 3 && arguments[3] == "keep-focus") {
        var pending = [window]
        while let element = pending.popLast() {
            if string(element, kAXRoleAttribute) == "AXWebArea" {
                AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
                break
            }
            if let children = attribute(element, kAXChildrenAttribute) as? [AXUIElement] {
                pending.append(contentsOf: children)
            }
        }
    }
    Thread.sleep(forTimeInterval: 0.4)
    print("parked")

case "set-value":
    guard arguments.count >= 5 else { fail("set-value needs a label and text.") }
    let role = arguments.count > 5 ? arguments[5] : nil
    guard let element = find(application, label: arguments[3], role: role) else {
        fail("No matching element was found: \(arguments[3])", code: 4)
    }
    AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
    let result = AXUIElementSetAttributeValue(
        element, kAXValueAttribute as CFString, arguments[4] as CFString
    )
    guard result == .success else {
        fail("Could not set the value of \(arguments[3]): \(result.rawValue)", code: 5)
    }
    print("set \(arguments[3])")

case "show-menu":
    guard arguments.count >= 4 else { fail("show-menu needs a label.") }
    let role = arguments.count > 4 ? arguments[4] : nil
    guard let element = find(application, label: arguments[3], role: role) else {
        fail("No matching element was found: \(arguments[3])", code: 4)
    }
    let result = AXUIElementPerformAction(element, "AXShowMenu" as CFString)
    guard result == .success else {
        fail("Could not show the menu for \(arguments[3]): \(result.rawValue)", code: 5)
    }
    print("menu \(arguments[3])")

case "key":
    guard arguments.count >= 4 else { fail("key needs a key name.") }
    let codes: [String: CGKeyCode] = [
        "escape": 53, "return": 36, "tab": 48, "down": 125, "up": 126
    ]
    guard let code = codes[arguments[3]] else {
        fail("Key must be escape, return, tab, down, or up.")
    }
    let count = arguments.count > 4 ? max(Int(arguments[4]) ?? 1, 1) : 1
    for _ in 0..<count {
        for isDown in [true, false] {
            CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: isDown)?.postToPid(pid)
        }
        Thread.sleep(forTimeInterval: 0.25)
    }
    print("key \(arguments[3]) x\(count)")

case "highlight-menu-item":
    guard arguments.count >= 4 else { fail("highlight-menu-item needs a label.") }
    let label = arguments[3]
    func selectedLabel() -> String? {
        var pending = [application]
        while let element = pending.popLast() {
            if string(element, kAXRoleAttribute) == "AXMenuItem",
               (attribute(element, kAXSelectedAttribute) as? Bool) == true
                || (attribute(element, kAXFocusedAttribute) as? Bool) == true {
                return [string(element, kAXTitleAttribute), string(element, kAXDescriptionAttribute)]
                    .first { !$0.isEmpty }
            }
            if let children = attribute(element, kAXChildrenAttribute) as? [AXUIElement] {
                pending.append(contentsOf: children)
            }
        }
        return nil
    }
    guard find(application, label: label, role: "AXMenuItem") != nil else {
        fail("No open menu item was found: \(label)", code: 4)
    }
    for _ in 0..<30 {
        if selectedLabel() == label {
            print("highlighted \(label)")
            exit(0)
        }
        for isDown in [true, false] {
            CGEvent(keyboardEventSource: nil, virtualKey: 125, keyDown: isDown)?.postToPid(pid)
        }
        Thread.sleep(forTimeInterval: 0.25)
    }
    fail("Could not confirm that \(label) is highlighted. Check the capture visually.", code: 6)

case "focus":
    guard arguments.count >= 4 else { fail("focus needs a label.") }
    let role = arguments.count > 4 ? arguments[4] : nil
    guard let element = find(application, label: arguments[3], role: role) else {
        fail("No matching element was found: \(arguments[3])", code: 4)
    }
    let result = AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
    guard result == .success else {
        fail("Could not focus \(arguments[3]): \(result.rawValue)", code: 5)
    }
    Thread.sleep(forTimeInterval: 0.8)
    print("focused \(arguments[3])")

case "dismiss-banners":
    let safeLabels: Set<String> = ["Close banner", "Later", "Not now", "Dismiss"]
    var dismissed = 0
    for _ in 0..<8 {
        guard let button = safeLabels.lazy.compactMap({
            find(application, label: $0, role: "AXButton")
        }).first else { break }
        guard AXUIElementPerformAction(button, kAXPressAction as CFString) == .success else {
            break
        }
        dismissed += 1
        Thread.sleep(forTimeInterval: 0.6)
    }
    print("dismissed=\(dismissed)")

default:
    fail("Mode must be hover, park, set-value, show-menu, key, highlight-menu-item, focus, or dismiss-banners.")
}
