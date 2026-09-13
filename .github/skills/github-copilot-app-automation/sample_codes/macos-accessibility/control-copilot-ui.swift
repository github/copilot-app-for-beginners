// Perform one named Accessibility action in an exact GitHub Copilot process.
//
// Usage:
//   control-copilot-ui <pid> <exists|press|open|confirm> <target> [role]
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

func findElement(
    in root: AXUIElement,
    target: String,
    role: String?
) -> AXUIElement? {
    var pending = [root]
    while let element = pending.popLast() {
        let values = [
            stringAttribute(element, kAXTitleAttribute as CFString),
            stringAttribute(element, kAXDescriptionAttribute as CFString),
            stringAttribute(element, kAXValueAttribute as CFString)
        ]
        let elementRole = stringAttribute(element, kAXRoleAttribute as CFString)
        if values.contains(target), role == nil || elementRole == role {
            return element
        }
        if let children = attribute(element, kAXChildrenAttribute as CFString) as? [AXUIElement] {
            pending.append(contentsOf: children.reversed())
        }
    }
    return nil
}

guard CommandLine.arguments.count >= 4,
      let rawPid = Int32(CommandLine.arguments[1]),
      rawPid > 0 else {
    fail("Usage: control-copilot-ui <pid> <exists|press|open|confirm> <target> [role]")
}

let actionNames: [String: CFString] = [
    "press": kAXPressAction as CFString,
    "open": "AXOpen" as CFString,
    "confirm": "AXConfirm" as CFString
]
let mode = CommandLine.arguments[2]
let target = CommandLine.arguments[3]
let role = CommandLine.arguments.count > 4 ? CommandLine.arguments[4] : nil

guard mode == "exists" || actionNames[mode] != nil else {
    fail("Action must be exists, press, open, or confirm.")
}
guard AXIsProcessTrusted() else {
    fail("Accessibility permission is required for the automation caller.", code: 2)
}

let application = AXUIElementCreateApplication(pid_t(rawPid))
guard let element = findElement(in: application, target: target, role: role) else {
    fail("No matching element was found: \(target)", code: 3)
}
if mode == "exists" {
    print(target)
    exit(0)
}
guard let action = actionNames[mode] else {
    fail("No Accessibility action was configured for \(mode).", code: 4)
}
let error = AXUIElementPerformAction(element, action)
guard error == .success else {
    fail("Could not perform \(mode) on \(target): \(error.rawValue)", code: 4)
}

print(target)
