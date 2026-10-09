import Foundation
import Testing
@testable import SensibleCore

private let supportDir = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("Support")

private func scratchStore() -> RuleStore {
    let suite = "sensible-defaults-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return RuleStore(defaults: defaults)
}

@Test func transportStreamIsDetected() {
    var ts = Data(count: 600)
    for offset in [0, 188, 376] { ts[offset] = 0x47 }
    #expect(FileKind.looksLikeTransportStream(ts))

    var m2ts = Data(count: 600)
    for offset in [4, 196, 388] { m2ts[offset] = 0x47 }
    #expect(FileKind.looksLikeTransportStream(m2ts))
}

@Test func typeScriptIsNotVideo() {
    #expect(!FileKind.looksLikeTransportStream(Data("export const answer: number = 42\n".utf8)))
    #expect(!FileKind.looksLikeTransportStream(Data()))
    // A source file may start with "G" (0x47); one sync byte is not enough.
    #expect(!FileKind.looksLikeTransportStream(Data(("GLOBAL = 1\n" + String(repeating: "x", count: 600)).utf8)))
}

@Test func extensionsIncludeDotfiles() {
    #expect(FileKind.fileExtension(of: URL(fileURLWithPath: "/tmp/Main.PY")) == "py")
    #expect(FileKind.fileExtension(of: URL(fileURLWithPath: "/tmp/.gitignore")) == "gitignore")
    #expect(FileKind.fileExtension(of: URL(fileURLWithPath: "/tmp/Makefile")) == "")
}

@Test func recentEditorsComeFirst() {
    let a = Editor(name: "A", bundleID: "a"), b = Editor(name: "B", bundleID: "b"), c = Editor(name: "C", bundleID: "c")
    #expect(EditorCatalog.order([a, b, c], recent: []) == [a, b, c])
    #expect(EditorCatalog.order([a, b, c], recent: ["C", "b"]) == [c, b, a])
    #expect(EditorCatalog.order([a, b, c], recent: ["not-installed", "b"]) == [b, a, c])
}

@Test func rulesAreNormalizedAndRemovable() {
    let store = scratchStore()
    store.setRule("com.microsoft.VSCode", for: ".PY ")
    #expect(store.rule(for: "py") == "com.microsoft.VSCode")
    store.setRule("dev.zed.Zed", for: "py")
    #expect(store.rules == ["py": "dev.zed.Zed"])
    store.setRule("dev.zed.Zed", for: "  ")
    #expect(store.rules.count == 1)
    store.removeRule(for: ".py")
    #expect(store.rule(for: "py") == nil)
    store.setRule("x", for: "rs")
    store.removeAllRules()
    #expect(store.rules.isEmpty)
}

@Test func usageHistoryIsMostRecentFirstWithoutDuplicates() {
    let store = scratchStore()
    store.noteUsed("a"); store.noteUsed("b"); store.noteUsed("A")
    #expect(store.recent == ["A", "b"])
    store.addCustomEditor("x"); store.addCustomEditor("X")
    #expect(store.customEditors == ["x"])
}

@Test func catalogueDecodesAndStartsWithVSCode() throws {
    let editors = try EditorCatalog.decode(Data(contentsOf: supportDir.appendingPathComponent("editors.json")))
    #expect(editors.first?.bundleID == "com.microsoft.VSCode")
    #expect(Set(editors.map { $0.bundleID.lowercased() }).count == editors.count)
}

@Test func infoPlistClaimsExactlyTheListedExtensions() throws {
    let listed = try String(contentsOf: supportDir.appendingPathComponent("extensions.txt"), encoding: .utf8)
        .split(separator: "\n").filter { !$0.hasPrefix("#") }
        .flatMap { $0.split(separator: " ").map(String.init) }
    #expect(Set(listed).count == listed.count, "duplicate extension in extensions.txt")

    let plist = try PropertyListSerialization.propertyList(
        from: Data(contentsOf: supportDir.appendingPathComponent("Info.plist")), format: nil) as! [String: Any]
    let types = plist["CFBundleDocumentTypes"] as! [[String: Any]]
    let claimed = types.flatMap { $0["CFBundleTypeExtensions"] as? [String] ?? [] }
    #expect(Set(claimed) == Set(listed))
    #expect(types.allSatisfy { $0["LSHandlerRank"] as? String == "Owner" })
}
