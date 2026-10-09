import Foundation

public enum FileKind {
    /// Lowercased extension without the dot. Dotfiles count as their own extension
    /// (`.gitignore` → `gitignore`), matching how they are claimed in Info.plist.
    public static func fileExtension(of url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        if !ext.isEmpty { return ext }
        let name = url.lastPathComponent.lowercased()
        return name.hasPrefix(".") ? String(name.dropFirst()) : ""
    }

    /// Extensions macOS types as MPEG transport streams although developers mean TypeScript.
    public static let ambiguousVideoExtensions: Set<String> = ["ts", "mts"]

    /// True when `head` (the first few hundred bytes of a file) is an MPEG transport stream:
    /// 0x47 sync bytes every 188 bytes, or every 192 bytes offset by 4 for M2TS/AVCHD.
    public static func looksLikeTransportStream(_ head: Data) -> Bool {
        let bytes = [UInt8](head)
        func synced(start: Int, packet: Int) -> Bool {
            let offsets = [start, start + packet, start + 2 * packet]
            return offsets.allSatisfy { $0 < bytes.count && bytes[$0] == 0x47 }
        }
        return synced(start: 0, packet: 188) || synced(start: 4, packet: 192)
    }
}
