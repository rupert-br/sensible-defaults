import AppKit
import UniformTypeIdentifiers

/// Which of the claimed extensions Launch Services currently routes to this app.
struct HandlerStatus {
    struct Holder {
        let appName: String
        let extensions: [String]
    }

    let claimed: Int
    let handled: Int
    let heldByOthers: [Holder]
    /// Distinct content types behind the extensions other apps still hold.
    let remainingTypes: [UTType]

    static func current() -> HandlerStatus {
        let types = Bundle.main.infoDictionary?["CFBundleDocumentTypes"] as? [[String: Any]] ?? []
        let extensions = types.flatMap { $0["CFBundleTypeExtensions"] as? [String] ?? [] }
        let me = Bundle.main.bundleIdentifier

        var handled = 0
        var others: [String: [String]] = [:]
        var remaining: [String: UTType] = [:]
        for ext in extensions {
            guard let type = UTType(filenameExtension: ext) else { continue }
            let handler = NSWorkspace.shared.urlForApplication(toOpen: type)
            if let handler, Bundle(url: handler)?.bundleIdentifier == me {
                handled += 1
            } else {
                let name = handler?.deletingPathExtension().lastPathComponent ?? "No app"
                others[name, default: []].append(ext)
                remaining[type.identifier] = type
            }
        }
        let holders = others.map { Holder(appName: $0.key, extensions: $0.value) }
            .sorted { $0.extensions.count > $1.extensions.count }
        return HandlerStatus(claimed: extensions.count, handled: handled, heldByOthers: holders,
                             remainingTypes: remaining.values.sorted { $0.identifier < $1.identifier })
    }
}
