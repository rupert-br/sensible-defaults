// Lists on-screen windows (including menus) of Sensible Defaults. Debug helper.
import CoreGraphics
import Foundation

let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
for window in windows where (window[kCGWindowOwnerName as String] as? String ?? "").contains("Sensible") {
    let bounds = window[kCGWindowBounds as String] as? [String: Any] ?? [:]
    print("layer \(window[kCGWindowLayer as String] ?? "?") size \(bounds["Width"] ?? "?")x\(bounds["Height"] ?? "?") at \(bounds["X"] ?? "?"),\(bounds["Y"] ?? "?")")
}
