import AppKit
import SensibleCore

/// The little menu shown at the cursor when developer files are opened.
final class ChooserMenu: NSObject {
    enum Choice {
        case open(InstalledEditor, always: Bool)
        case other
        case editRules
    }

    private let files: [URL]
    private let editors: [InstalledEditor]
    private var choice: Choice?

    init(files: [URL], editors: [InstalledEditor]) {
        self.files = files
        self.editors = editors
    }

    /// Blocks until the user picks something or dismisses the menu.
    func run() -> Choice? {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let header = NSMenuItem(title: headerTitle, action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        for (index, editor) in editors.enumerated() {
            let item = editorItem(editor, action: #selector(pick(_:)))
            if index < 9 { item.keyEquivalent = String(index + 1); item.keyEquivalentModifierMask = [] }
            menu.addItem(item)
        }
        if !editors.isEmpty { menu.addItem(.separator()) }

        if let ext = sharedExtension, !editors.isEmpty {
            let always = NSMenuItem(title: "Always Open .\(ext) With", action: nil, keyEquivalent: "")
            let submenu = NSMenu()
            submenu.autoenablesItems = false
            editors.forEach { submenu.addItem(editorItem($0, action: #selector(pickAlways(_:)))) }
            always.submenu = submenu
            menu.addItem(always)
        }
        menu.addItem(plainItem("Other…", #selector(pickOther)))
        menu.addItem(.separator())
        menu.addItem(plainItem("Edit Rules…", #selector(pickEditRules)))

        NSApp.activate(ignoringOtherApps: true)
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        return choice
    }

    private var headerTitle: String {
        files.count == 1 ? "Open “\(files[0].lastPathComponent)” with" : "Open \(files.count) files with"
    }

    /// The extension all files share, if they do.
    private var sharedExtension: String? {
        let exts = Set(files.map(FileKind.fileExtension(of:)))
        guard exts.count == 1, let ext = exts.first, !ext.isEmpty else { return nil }
        return ext
    }

    private func editorItem(_ editor: InstalledEditor, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: editor.name, action: action, keyEquivalent: "")
        item.target = self
        item.image = editor.icon
        item.representedObject = editor.bundleID
        return item
    }

    private func plainItem(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func editor(for sender: NSMenuItem) -> InstalledEditor? {
        editors.first { $0.bundleID == sender.representedObject as? String }
    }

    @objc private func pick(_ sender: NSMenuItem) {
        if let editor = editor(for: sender) { choice = .open(editor, always: false) }
    }

    @objc private func pickAlways(_ sender: NSMenuItem) {
        if let editor = editor(for: sender) { choice = .open(editor, always: true) }
    }

    @objc private func pickOther() { choice = .other }
    @objc private func pickEditRules() { choice = .editRules }
}
