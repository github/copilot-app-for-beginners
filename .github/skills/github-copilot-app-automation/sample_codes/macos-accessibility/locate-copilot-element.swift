// Print where named controls appear in the final 1920x1080 course screenshot.
//
// Use this to place --callout badges and --box outlines for capture-window.sh
// without guessing pixel positions. Coordinates are converted from screen
// points to the finalized image, so they stay correct when the window frame
// or display scale changes.
//
// Usage:
//   locate-copilot-element <pid> <label> [role] [--contains]
//
// Matching compares the title, description, and value attributes. By default
// the label must match exactly. Add --contains to match part of a label.
//
// Output (one line per match):
//   role=AXButton label="Pull requests" left=.. top=.. right=.. bottom=.. center=X:Y
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

let arguments = CommandLine.arguments.filter { $0 != "--contains" }
let containsMatch = CommandLine.arguments.contains("--contains")
guard arguments.count >= 3,
      let rawPid = Int32(arguments[1]),
      rawPid > 0 else {
    fail("Usage: locate-copilot-element <pid> <label> [role] [--contains]")
}
guard AXIsProcessTrusted() else {
    fail("Accessibility permission is required for the automation caller.", code: 2)
}

let label = arguments[2]
let role = arguments.count > 3 ? arguments[3] : nil
let application = AXUIElementCreateApplication(pid_t(rawPid))
guard let window = mainWindow(application),
      let windowFrame = rect(window),
      windowFrame.width > 0,
      windowFrame.height > 0 else {
    fail("Process \(rawPid) has no accessible window.", code: 3)
}

let scaleX = 1920 / windowFrame.width
let scaleY = 1080 / windowFrame.height
var pending = [application]
var found = 0
while let element = pending.popLast() {
    let values = [
        string(element, kAXTitleAttribute),
        string(element, kAXDescriptionAttribute),
        string(element, kAXValueAttribute)
    ]
    let elementRole = string(element, kAXRoleAttribute)
    let matches = values.contains { value in
        containsMatch ? value.localizedCaseInsensitiveContains(label) : value == label
    }
    if matches, role == nil || elementRole == role, let frame = rect(element),
       frame.width > 0, frame.height > 0,
       frame.intersects(windowFrame) {
        let left = Int(((frame.minX - windowFrame.minX) * scaleX).rounded())
        let top = Int(((frame.minY - windowFrame.minY) * scaleY).rounded())
        let right = Int(((frame.maxX - windowFrame.minX) * scaleX).rounded())
        let bottom = Int(((frame.maxY - windowFrame.minY) * scaleY).rounded())
        let shown = (values.first { !$0.isEmpty } ?? label)
            .replacingOccurrences(of: "\n", with: " ")
            .prefix(80)
        print("role=\(elementRole) label=\"\(shown)\" left=\(left) top=\(top) right=\(right) bottom=\(bottom) center=\((left + right) / 2):\((top + bottom) / 2)")
        found += 1
    }
    if let children = attribute(element, kAXChildrenAttribute) as? [AXUIElement] {
        pending.append(contentsOf: children.reversed())
    }
}

if found == 0 {
    fail("No visible element matched \(label).", code: 4)
}
