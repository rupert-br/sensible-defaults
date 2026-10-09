import AppKit
import SensibleCore
import UniformTypeIdentifiers

/// Decides what happens to opened files: forward real video, apply a saved rule, or ask.
struct Router {
    let store: RuleStore

    struct Plan {
        var direct: [(app: URL, files: [URL])] = []
        var ask: [URL] = []
    }

    func plan(for urls: [URL], forceMenu: Bool) -> Plan {
        var byApp: [URL: [URL]] = [:]
        var plan = Plan()
        for url in urls {
            let ext = FileKind.fileExtension(of: url)
            if FileKind.ambiguousVideoExtensions.contains(ext), isTransportStream(url), let player = otherHandler(for: url) {
                byApp[player, default: []].append(url)
            } else if !forceMenu, let bundleID = store.rule(for: ext),
                      let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                byApp[app, default: []].append(url)
            } else {
                plan.ask.append(url)
            }
        }
        plan.direct = byApp.map { (app: $0.key, files: $0.value) }
        return plan
    }

    private func isTransportStream(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        return FileKind.looksLikeTransportStream((try? handle.read(upToCount: 600)) ?? Data())
    }

    /// The best app for this file that is neither us nor a code editor, e.g. a video player.
    private func otherHandler(for url: URL) -> URL? {
        var excluded = Set(InstalledEditors.catalog.map { $0.bundleID.lowercased() })
        excluded.formUnion(store.customEditors.map { $0.lowercased() })
        excluded.insert(Bundle.main.bundleIdentifier?.lowercased() ?? "")
        return NSWorkspace.shared.urlsForApplications(toOpen: url).first {
            guard let id = Bundle(url: $0)?.bundleIdentifier else { return false }
            return !excluded.contains(id.lowercased())
        }
    }
}
