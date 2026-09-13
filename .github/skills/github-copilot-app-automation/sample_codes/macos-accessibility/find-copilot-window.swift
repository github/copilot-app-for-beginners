// Lists on-screen GitHub Copilot app windows via CoreGraphics.
//
// Output (one line per window):
//   id=<n>|pid=<n>|layer=<n>|w=<n>|h=<n>|x=<n>|y=<n>|name=<title>
//
// IMPORTANT: CoreGraphics only reports windows on the CURRENT macOS Space.
// A Copilot window on a different desktop/Space (or another display the
// capture context cannot see) will NOT appear here and cannot be captured
// with `screencapture`. Move the app onto the active Space first.
//
// Run:   swift find-copilot-window.swift
// Build: swiftc find-copilot-window.swift -o find-copilot-window
import CoreGraphics
import Foundation

let opt: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
guard let list = CGWindowListCopyWindowInfo(opt, kCGNullWindowID) as? [[String: Any]] else {
    exit(0)
}

for w in list {
    let owner = ((w[kCGWindowOwnerName as String] as? String) ?? "").lowercased()
    // The bundle's executable is "github"; the display name is "GitHub Copilot".
    guard owner.contains("copilot") || owner == "github" else { continue }

    let num = (w[kCGWindowNumber as String] as? NSNumber)?.intValue ?? -1
    let pid = (w[kCGWindowOwnerPID as String] as? NSNumber)?.intValue ?? -1
    let layer = (w[kCGWindowLayer as String] as? NSNumber)?.intValue ?? -1
    let name = (w[kCGWindowName as String] as? String) ?? ""

    var x = 0, y = 0, wd = 0, ht = 0
    if let b = w[kCGWindowBounds as String] as? [String: Any] {
        x = Int((b["X"] as? NSNumber)?.doubleValue ?? 0)
        y = Int((b["Y"] as? NSNumber)?.doubleValue ?? 0)
        wd = Int((b["Width"] as? NSNumber)?.doubleValue ?? 0)
        ht = Int((b["Height"] as? NSNumber)?.doubleValue ?? 0)
    }
    print("id=\(num)|pid=\(pid)|layer=\(layer)|w=\(wd)|h=\(ht)|x=\(x)|y=\(y)|name=\(name)")
}
