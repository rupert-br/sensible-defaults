import AppKit
import SensibleCore

struct InstalledEditor {
    let bundleID: String
    let name: String
    let url: URL

    var icon: NSImage {
        let image = NSWorkspace.shared.icon(forFile: url.path)
        image.size = NSSize(width: 16, height: 16)
        return image
    }

    init?(bundleID: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        self.bundleID = bundleID
        self.url = url
        self.name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }
}

enum InstalledEditors {
    static let catalog: [Editor] = {
        guard let url = Bundle.main.url(forResource: "editors", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let editors = try? EditorCatalog.decode(data) else { return [] }
        return editors
    }()

    /// Catalogue editors plus apps added through "Other…", limited to what is installed,
    /// most recently used first.
    static func all(store: RuleStore) -> [InstalledEditor] {
        let custom = store.customEditors.map { Editor(name: $0, bundleID: $0) }
        let ordered = EditorCatalog.order(catalog + custom, recent: store.recent)
        var seen = Set<String>()
        return ordered.compactMap { editor in
            guard seen.insert(editor.bundleID.lowercased()).inserted else { return nil }
            return InstalledEditor(bundleID: editor.bundleID)
        }
    }
}
