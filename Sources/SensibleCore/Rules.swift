import Foundation

/// Extension → editor rules and usage history, kept in the app's own preferences
/// (never in Launch Services, so changing them triggers no system prompts).
public final class RuleStore {
    private let defaults: UserDefaults
    private let rulesKey = "rules"
    private let recentKey = "recentEditors"
    private let customKey = "customEditors"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public static func normalize(_ ext: String) -> String {
        var e = ext.trimmingCharacters(in: .whitespaces).lowercased()
        while e.hasPrefix(".") { e.removeFirst() }
        return e
    }

    /// Extension (lowercase, no dot) → bundle identifier.
    public var rules: [String: String] {
        get { defaults.dictionary(forKey: rulesKey) as? [String: String] ?? [:] }
        set { defaults.set(newValue, forKey: rulesKey) }
    }

    public func rule(for ext: String) -> String? {
        rules[Self.normalize(ext)]
    }

    public func setRule(_ bundleID: String, for ext: String) {
        let e = Self.normalize(ext)
        guard !e.isEmpty else { return }
        rules[e] = bundleID
    }

    public func removeRule(for ext: String) {
        rules[Self.normalize(ext)] = nil
    }

    public func removeAllRules() {
        defaults.removeObject(forKey: rulesKey)
    }

    /// Bundle identifiers of editors picked from the menu, most recent first.
    public var recent: [String] {
        defaults.stringArray(forKey: recentKey) ?? []
    }

    public func noteUsed(_ bundleID: String) {
        var r = recent.filter { $0.caseInsensitiveCompare(bundleID) != .orderedSame }
        r.insert(bundleID, at: 0)
        defaults.set(Array(r.prefix(20)), forKey: recentKey)
    }

    /// Apps the user added through "Other…" that are not in the catalogue.
    public var customEditors: [String] {
        defaults.stringArray(forKey: customKey) ?? []
    }

    public func addCustomEditor(_ bundleID: String) {
        guard !customEditors.contains(where: { $0.caseInsensitiveCompare(bundleID) == .orderedSame }) else { return }
        defaults.set(customEditors + [bundleID], forKey: customKey)
    }
}
