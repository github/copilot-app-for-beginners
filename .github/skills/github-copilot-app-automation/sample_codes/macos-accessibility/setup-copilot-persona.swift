// Register one exact local repository in a fresh GitHub Copilot persona.
//
// Usage:
//   setup-copilot-persona <pid> <repository_path> [timeout_seconds]
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

func findElement(
    in root: AXUIElement,
    target: String,
    role: String? = nil
) -> AXUIElement? {
    allElements(in: root).first { element in
        let values = [
            stringAttribute(element, kAXTitleAttribute as CFString),
            stringAttribute(element, kAXDescriptionAttribute as CFString),
            stringAttribute(element, kAXValueAttribute as CFString)
        ]
        let elementRole = stringAttribute(element, kAXRoleAttribute as CFString)
        return values.contains(target) && (role == nil || elementRole == role)
    }
}

func waitForElement(
    in root: AXUIElement,
    target: String,
    role: String? = nil,
    until deadline: Date
) -> AXUIElement? {
    while Date() < deadline {
        if let element = findElement(in: root, target: target, role: role) {
            return element
        }
        Thread.sleep(forTimeInterval: 0.25)
    }
    return nil
}

func press(_ element: AXUIElement, label: String) {
    let error = AXUIElementPerformAction(element, kAXPressAction as CFString)
    guard error == .success else {
        fail("Could not press \(label): \(error.rawValue)", code: 5)
    }
}

func perform(_ action: CFString, on element: AXUIElement, label: String) {
    let error = AXUIElementPerformAction(element, action)
    guard error == .success else {
        fail("Could not perform \(action) on \(label): \(error.rawValue)", code: 6)
    }
}

func findOpenableValue(
    in root: AXUIElement,
    value: String
) -> AXUIElement? {
    allElements(in: root).first { element in
        stringAttribute(element, kAXRoleAttribute as CFString) == kAXTextFieldRole as String
            && stringAttribute(element, kAXValueAttribute as CFString) == value
    }
}

func waitForOpenableValue(
    in root: AXUIElement,
    value: String,
    until deadline: Date
) -> AXUIElement? {
    while Date() < deadline {
        if let element = findOpenableValue(in: root, value: value) {
            return element
        }
        Thread.sleep(forTimeInterval: 0.25)
    }
    return nil
}

guard CommandLine.arguments.count >= 3,
      let rawPid = Int32(CommandLine.arguments[1]),
      rawPid > 0 else {
    fail("Usage: setup-copilot-persona <pid> <repository_path> [timeout_seconds]")
}

let pid = pid_t(rawPid)
let repositoryURL = URL(fileURLWithPath: CommandLine.arguments[2]).standardizedFileURL
let timeout = CommandLine.arguments.count > 3
    ? max(Double(CommandLine.arguments[3]) ?? 45, 1)
    : 45
let deadline = Date().addingTimeInterval(timeout)
let repositoryName = repositoryURL.lastPathComponent

var isDirectory: ObjCBool = false
guard FileManager.default.fileExists(atPath: repositoryURL.path, isDirectory: &isDirectory),
      isDirectory.boolValue,
      FileManager.default.fileExists(atPath: repositoryURL.appendingPathComponent(".git").path) else {
    fail("Repository path is not a Git repository: \(repositoryURL.path)", code: 2)
}
guard AXIsProcessTrusted() else {
    fail("Accessibility permission is required for the automation caller.", code: 3)
}
guard let runningApplication = NSRunningApplication(processIdentifier: pid) else {
    fail("Process \(pid) is not running.", code: 4)
}

let application = AXUIElementCreateApplication(pid)
_ = runningApplication.activate(options: [.activateAllWindows])

guard let openRepository = waitForElement(
    in: application,
    target: "Create from Local Folder or Repository",
    role: kAXMenuItemRole as String,
    until: deadline
) else {
    fail("The local repository command did not appear.", code: 5)
}
press(openRepository, label: "Create from Local Folder or Repository")

guard let browseButton = waitForElement(
    in: application,
    target: "Browse...",
    role: kAXButtonRole as String,
    until: deadline
) else {
    fail("The local repository dialog did not appear.", code: 6)
}
press(browseButton, label: "Browse...")

guard waitForElement(
    in: application,
    target: "open",
    role: kAXSheetRole as String,
    until: deadline
) != nil else {
    fail("The repository folder picker did not appear.", code: 7)
}

guard let repositoryFolder = waitForOpenableValue(
    in: application,
    value: repositoryName,
    until: deadline
) else {
    fail(
        "Repository folder did not appear in the native picker: \(repositoryURL.path)",
        code: 8
    )
}
guard let folderItemValue = attribute(repositoryFolder, kAXParentAttribute as CFString) else {
    fail("The repository folder item was not accessible.", code: 8)
}
let folderItem = unsafeBitCast(folderItemValue, to: AXUIElement.self)
guard let folderListValue = attribute(folderItem, kAXParentAttribute as CFString) else {
    fail("The repository folder list was not accessible.", code: 8)
}
let folderList = unsafeBitCast(folderListValue, to: AXUIElement.self)
let selectionError = AXUIElementSetAttributeValue(
    folderList,
    kAXSelectedChildrenAttribute as CFString,
    [folderItem] as CFArray
)
guard selectionError == .success else {
    fail("Could not select repository folder \(repositoryName): \(selectionError.rawValue)", code: 8)
}
Thread.sleep(forTimeInterval: 0.5)

guard let openButton = waitForElement(
    in: application,
    target: "Open",
    role: kAXButtonRole as String,
    until: deadline
) else {
    fail("The Open button did not appear.", code: 9)
}
Thread.sleep(forTimeInterval: 1)
press(openButton, label: "Open")

while Date() < deadline {
    let values = allElements(in: application).flatMap { element in
        [
            stringAttribute(element, kAXTitleAttribute as CFString),
            stringAttribute(element, kAXDescriptionAttribute as CFString),
            stringAttribute(element, kAXValueAttribute as CFString)
        ]
    }
    if values.contains(where: { $0 == repositoryName || $0.contains(repositoryName) }) {
        print(repositoryURL.path)
        exit(0)
    }
    Thread.sleep(forTimeInterval: 0.5)
}

fail("The app did not confirm repository \(repositoryName) before the timeout.", code: 10)
