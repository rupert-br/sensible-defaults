import AppKit
import os
import SensibleCore
import UniformTypeIdentifiers

let log = Logger(subsystem: "io.github.rupert-br.sensible-defaults", category: "router")

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = RuleStore()
    private var settings: SettingsWindowController?
    private var receivedFiles = false
    private var pendingOpens = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = Self.mainMenu()
        // `--register` is used by installers: launching once makes Launch Services honour the claims.
        if CommandLine.arguments.contains("--register") {
            NSApp.terminate(nil)
            return
        }
        // `--snapshot <png>` renders the settings window to a file (for docs and UI checks).
        if let index = CommandLine.arguments.firstIndex(of: "--snapshot"), CommandLine.arguments.count > index + 1 {
            let path = CommandLine.arguments[index + 1]
            showSettings()
            if let view = settings?.window?.contentView {
                // The window draws its own backdrop; an offscreen render needs an explicit one.
                view.wantsLayer = true
                view.effectiveAppearance.performAsCurrentDrawingAppearance {
                    view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
                if let view = settings?.window?.contentView, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                    view.cacheDisplay(in: view.bounds, to: rep)
                    try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
                }
                NSApp.terminate(nil)
            }
            return
        }
        // Files from Finder arrive just after launch; with none, the app was opened directly.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [self] in
            if !receivedFiles { showSettings() }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        receivedFiles = true
        let forceMenu = NSEvent.modifierFlags.contains(.option)
        // Let the open event return before the menu starts its own event loop.
        DispatchQueue.main.async { [self] in handle(urls, forceMenu: forceMenu) }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    private func handle(_ urls: [URL], forceMenu: Bool) {
        let plan = Router(store: store).plan(for: urls, forceMenu: forceMenu)
        for group in plan.direct { open(group.files, with: group.app) }
        if !plan.ask.isEmpty { ask(plan.ask) }
        quitIfIdle()
    }

    private func ask(_ files: [URL]) {
        let editors = InstalledEditors.all(store: store)
        log.notice("asking for \(files.count) file(s); editors: \(editors.map(\.name).joined(separator: ", "), privacy: .public)")
        switch ChooserMenu(files: files, editors: editors).run() {
        case let .open(editor, always):
            store.noteUsed(editor.bundleID)
            if always { store.setRule(editor.bundleID, for: FileKind.fileExtension(of: files[0])) }
            settings?.reload()
            open(files, with: editor.url)
        case .other:
            if let app = chooseOtherApp(), let bundleID = Bundle(url: app)?.bundleIdentifier {
                store.addCustomEditor(bundleID)
                store.noteUsed(bundleID)
                open(files, with: app)
            }
        case .editRules:
            showSettings()
        case nil:
            log.notice("menu dismissed")
        }
    }

    private func open(_ files: [URL], with app: URL) {
        pendingOpens += 1
        log.notice("opening \(files.count) file(s) with \(app.lastPathComponent, privacy: .public)")
        NSWorkspace.shared.open(files, withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            DispatchQueue.main.async { [self] in
                pendingOpens -= 1
                if let error { NSAlert(error: error).runModal() }
                quitIfIdle()
            }
        }
    }

    private func chooseOtherApp() -> URL? {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.prompt = "Open"
        panel.message = "Choose an application to open the file with."
        NSApp.activate(ignoringOtherApps: true)
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func showSettings() {
        if settings == nil { settings = SettingsWindowController(store: store) }
        settings?.reload()
        NSApp.activate(ignoringOtherApps: true)
        settings?.showWindow(nil)
        settings?.window?.makeKeyAndOrderFront(nil)
    }

    /// The app only lives as long as it has something to show or deliver.
    private func quitIfIdle() {
        if pendingOpens == 0, settings?.window?.isVisible != true { NSApp.terminate(nil) }
    }

    /// Never shown (the app is an accessory), but provides ⌘Q, ⌘W and text editing shortcuts.
    private static func mainMenu() -> NSMenu {
        let main = NSMenu()
        let appItem = NSMenuItem()
        appItem.submenu = NSMenu()
        appItem.submenu?.addItem(withTitle: "Quit Sensible Defaults", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        main.addItem(appItem)

        let fileItem = NSMenuItem()
        fileItem.submenu = NSMenu(title: "File")
        fileItem.submenu?.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        main.addItem(fileItem)

        let editItem = NSMenuItem()
        editItem.submenu = NSMenu(title: "Edit")
        editItem.submenu?.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editItem.submenu?.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editItem.submenu?.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editItem.submenu?.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        main.addItem(editItem)
        return main
    }
}
