// Find personal identity text exposed by one GitHub Copilot app process.
//
// The profile name comes from the "<name>, open user menu" accessibility label.
// Account handles and repository owners are included only when their normalized
// value matches the normalized profile name. This avoids hard-coded names and
// preserves unrelated people and organizations.
//
// Usage:
//   find-private-identities <pid>
//
// Output:
//   {"accountNames":["exampleperson"],"displayNames":["Example Person"],"repositoryOwners":["exampleperson"]}
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

func stringAttribute(_ element: AXUIElement, _ name: CFString) -> String? {
    attribute(element, name) as? String
}

func normalizedIdentity(_ value: String) -> String {
    value.lowercased().unicodeScalars
        .filter { CharacterSet.alphanumerics.contains($0) }
        .map(String.init)
        .joined()
}

guard CommandLine.arguments.count == 2,
      let rawPid = Int32(CommandLine.arguments[1]),
      rawPid > 0 else {
    fail("Usage: find-private-identities <pid>")
}

let app = AXUIElementCreateApplication(pid_t(rawPid))
var pending = [app]
var values = Set<String>()

while let element = pending.popLast() {
    for name in [
        kAXTitleAttribute as CFString,
        kAXDescriptionAttribute as CFString,
        kAXValueAttribute as CFString
    ] {
        if let value = stringAttribute(element, name), !value.isEmpty {
            values.insert(value)
        }
    }

    if let children = attribute(element, kAXChildrenAttribute as CFString) as? [AXUIElement] {
        pending.append(contentsOf: children)
    }
}

let profileSuffix = ", open user menu"
var displayNames = Set(values.compactMap { value -> String? in
    guard value.lowercased().hasSuffix(profileSuffix) else {
        return nil
    }
    let end = value.index(value.endIndex, offsetBy: -profileSuffix.count)
    let name = value[..<end].trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty, name.caseInsensitiveCompare("Copilot Dev") != .orderedSame else {
        return nil
    }
    return name
})

let accountLabelPattern = try NSRegularExpression(
    pattern: #"^(.+?)\s+@([A-Za-z0-9_.-]+)$"#
)
for value in values {
    let range = NSRange(value.startIndex..<value.endIndex, in: value)
    guard let match = accountLabelPattern.firstMatch(in: value, range: range),
          let nameRange = Range(match.range(at: 1), in: value),
          let accountRange = Range(match.range(at: 2), in: value) else {
        continue
    }
    let name = String(value[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    let account = String(value[accountRange])
    if normalizedIdentity(name) == normalizedIdentity(account),
       name.caseInsensitiveCompare("Copilot Dev") != .orderedSame {
        displayNames.insert(name)
    }
}

let normalizedNames = Set(displayNames.map(normalizedIdentity))
let ownerPattern = try NSRegularExpression(
    pattern: #"(?<![A-Za-z0-9_.-])([A-Za-z0-9_.-]+)/[A-Za-z0-9_.-]+"#
)
var repositoryOwners = Set<String>()
var accountNames = Set<String>()

let accountPattern = try NSRegularExpression(pattern: #"[A-Za-z0-9_.-]+"#)
for value in values {
    let range = NSRange(value.startIndex..<value.endIndex, in: value)
    for match in accountPattern.matches(in: value, range: range) {
        guard let tokenRange = Range(match.range, in: value) else {
            continue
        }
        let token = String(value[tokenRange])
        if normalizedNames.contains(normalizedIdentity(token)),
           token.caseInsensitiveCompare("copilotdev") != .orderedSame {
            accountNames.insert(token)
        }
    }
}

for value in values {
    let range = NSRange(value.startIndex..<value.endIndex, in: value)
    for match in ownerPattern.matches(in: value, range: range) {
        guard let ownerRange = Range(match.range(at: 1), in: value) else {
            continue
        }
        let owner = String(value[ownerRange])
        let normalizedOwner = normalizedIdentity(owner)
        if !normalizedOwner.isEmpty,
           normalizedNames.contains(normalizedOwner),
           owner.caseInsensitiveCompare("copilotdev") != .orderedSame {
            repositoryOwners.insert(owner)
        }
    }
}

let result: [String: [String]] = [
    "accountNames": accountNames.sorted(),
    "displayNames": displayNames.sorted(),
    "repositoryOwners": repositoryOwners.sorted()
]
let data = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
print(String(decoding: data, as: UTF8.self))
