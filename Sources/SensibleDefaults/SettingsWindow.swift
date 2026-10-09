import AppKit
import SensibleCore
import UniformTypeIdentifiers

/// The small rules editor: extension → app, plus a footer showing what the app currently handles.
final class SettingsWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
    private struct Row {
        var ext: String
        var bundleID: String
    }

    private let store: RuleStore
    private var rows: [Row] = []
    private var editors: [InstalledEditor] = []
    private var status = HandlerStatus.current()

    private let table = NSTableView()
    private let removeButton = NSButton(title: "−", target: nil, action: nil)
    private let statusLabel = NSTextField(wrappingLabelWithString: "")
    private let claimButton = NSButton(title: "Claim Remaining…", target: nil, action: nil)

    private static let extColumn = NSUserInterfaceItemIdentifier("ext")
    private static let editorColumn = NSUserInterfaceItemIdentifier("editor")

    init(store: RuleStore) {
        self.store = store
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 470),
                              styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Sensible Defaults"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildUI()
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    // MARK: Layout

    private func buildUI() {
        let title = NSTextField(labelWithString: "Rules")
        title.font = .boldSystemFont(ofSize: 15)
        let intro = NSTextField(wrappingLabelWithString:
            "Developer files normally open a menu of your editors. File types listed here skip the menu "
            + "and open straight in the chosen app. Hold ⌥ while opening a file to get the menu anyway.")
        intro.textColor = .secondaryLabelColor
        intro.font = .systemFont(ofSize: 12)

        let extColumn = NSTableColumn(identifier: Self.extColumn)
        extColumn.title = "Extension"
        extColumn.width = 120
        let editorColumn = NSTableColumn(identifier: Self.editorColumn)
        editorColumn.title = "Opens with"
        editorColumn.width = 290
        table.addTableColumn(extColumn)
        table.addTableColumn(editorColumn)
        table.rowHeight = 28
        table.usesAlternatingRowBackgroundColors = true
        table.dataSource = self
        table.delegate = self

        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.heightAnchor.constraint(equalToConstant: 200).isActive = true

        let addButton = NSButton(title: "+", target: self, action: #selector(addRule))
        removeButton.target = self
        removeButton.action = #selector(removeRule)
        let resetButton = NSButton(title: "Reset All", target: self, action: #selector(resetAll))
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let buttons = NSStackView(views: [addButton, removeButton, spacer, resetButton])

        let separator = NSBox()
        separator.boxType = .separator

        statusLabel.font = .systemFont(ofSize: 12)
        claimButton.target = self
        claimButton.action = #selector(claimRemaining)
        let uninstall = NSTextField(wrappingLabelWithString:
            "To uninstall, move Sensible Defaults to the Trash. Your previous default apps come back on their own.")
        uninstall.textColor = .secondaryLabelColor
        uninstall.font = .systemFont(ofSize: 11)

        let stack = NSStackView(views: [title, intro, scroll, buttons, separator, statusLabel, claimButton, uninstall])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 18, left: 20, bottom: 18, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false
        for view in [intro, scroll, buttons, separator, statusLabel, uninstall] {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -40).isActive = true
        }

        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            content.widthAnchor.constraint(equalToConstant: 480),
        ])
        window?.contentView = content
    }

    // MARK: Data

    func reload() {
        editors = InstalledEditors.all(store: store).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        rows = store.rules.map { Row(ext: $0.key, bundleID: $0.value) }.sorted { $0.ext < $1.ext }
        table.reloadData()
        refreshStatus()
        updateButtons()
    }

    private func refreshStatus() {
        status = HandlerStatus.current()
        var text = "Handling \(status.handled) of \(status.claimed) developer file types."
        if !status.heldByOthers.isEmpty {
            let holders = status.heldByOthers.map { holder in
                "\(holder.appName): " + holder.extensions.map { "." + $0 }.joined(separator: " ")
            }
            text += "\nStill opened by other apps — " + holders.joined(separator: "; ")
        }
        statusLabel.stringValue = text
        claimButton.isHidden = status.remainingTypes.isEmpty
    }

    private func updateButtons() {
        removeButton.isEnabled = table.selectedRow >= 0
    }

    // MARK: Table

    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let rule = rows[row]
        if tableColumn?.identifier == Self.extColumn {
            let field = NSTextField(string: rule.ext.isEmpty ? "" : "." + rule.ext)
            field.placeholderString = ".ext"
            field.isBordered = false
            field.drawsBackground = false
            field.delegate = self
            return centered(field)
        }
        let popup = NSPopUpButton()
        popup.isBordered = false
        popup.target = self
        popup.action = #selector(editorChanged(_:))
        for editor in editors {
            popup.addItem(withTitle: editor.name)
            popup.lastItem?.image = editor.icon
            popup.lastItem?.representedObject = editor.bundleID
        }
        if !editors.contains(where: { $0.bundleID.caseInsensitiveCompare(rule.bundleID) == .orderedSame }) {
            popup.addItem(withTitle: "Not installed (\(rule.bundleID))")
            popup.lastItem?.representedObject = rule.bundleID
        }
        popup.menu?.addItem(.separator())
        popup.addItem(withTitle: "Ask every time")
        let index = popup.itemArray.firstIndex {
            ($0.representedObject as? String)?.caseInsensitiveCompare(rule.bundleID) == .orderedSame
        }
        popup.selectItem(at: index ?? 0)
        return centered(popup)
    }

    /// Wraps a control so it sits vertically centred in its table cell.
    private func centered(_ control: NSView) -> NSView {
        let cell = NSView()
        control.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(control)
        NSLayoutConstraint.activate([
            control.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
            control.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -2),
            control.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) { updateButtons() }

    // MARK: Editing

    func controlTextDidEndEditing(_ notification: Notification) {
        guard let field = notification.object as? NSTextField else { return }
        let row = table.row(for: field)
        guard rows.indices.contains(row) else { return }
        let newExt = RuleStore.normalize(field.stringValue)
        let old = rows[row]
        guard newExt != old.ext else { return }
        if !old.ext.isEmpty { store.removeRule(for: old.ext) }
        if !newExt.isEmpty { store.setRule(old.bundleID, for: newExt) }
        // Reload after the field editor has finished, or the table drops the edit mid-flight.
        DispatchQueue.main.async { [self] in reload() }
    }

    @objc private func editorChanged(_ sender: NSPopUpButton) {
        let row = table.row(for: sender)
        guard rows.indices.contains(row) else { return }
        if let bundleID = sender.selectedItem?.representedObject as? String {
            rows[row].bundleID = bundleID
            if !rows[row].ext.isEmpty { store.setRule(bundleID, for: rows[row].ext) }
        } else {
            // "Ask every time" means no rule.
            store.removeRule(for: rows[row].ext)
            reload()
        }
    }

    @objc private func addRule() {
        guard let first = editors.first else { return }
        window?.makeFirstResponder(nil)
        rows.append(Row(ext: "", bundleID: first.bundleID))
        table.reloadData()
        let row = rows.count - 1
        table.selectRowIndexes([row], byExtendingSelection: false)
        table.scrollRowToVisible(row)
        if let field = table.view(atColumn: 0, row: row, makeIfNecessary: true)?.subviews.first {
            window?.makeFirstResponder(field)
        }
    }

    @objc private func removeRule() {
        let row = table.selectedRow
        guard rows.indices.contains(row) else { return }
        window?.makeFirstResponder(nil)
        store.removeRule(for: rows[row].ext)
        reload()
    }

    @objc private func resetAll() {
        window?.makeFirstResponder(nil)
        store.removeAllRules()
        reload()
    }

    // MARK: Claiming types other apps still hold

    @objc private func claimRemaining() {
        let types = status.remainingTypes
        guard !types.isEmpty, let window else { return }
        let alert = NSAlert()
        alert.messageText = "Claim \(types.count) remaining file type\(types.count == 1 ? "" : "s")?"
        alert.informativeText = "macOS asks you to confirm each one separately. Choose “Keep” in a dialog to leave that type with its current app."
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: window) { [self] response in
            if response == .alertFirstButtonReturn { claim(types[...]) }
        }
    }

    private func claim(_ types: ArraySlice<UTType>) {
        guard let type = types.first else {
            refreshStatus()
            return
        }
        NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpen: type) { _ in
            DispatchQueue.main.async { [self] in claim(types.dropFirst()) }
        }
    }
}
