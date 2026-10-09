import Foundation

public struct Editor: Codable, Equatable {
    public let name: String
    public let bundleID: String

    public init(name: String, bundleID: String) {
        self.name = name
        self.bundleID = bundleID
    }
}

public enum EditorCatalog {
    /// Decodes the catalogue shipped as `editors.json`.
    public static func decode(_ data: Data) throws -> [Editor] {
        try JSONDecoder().decode([Editor].self, from: data)
    }

    /// Recently used editors first (most recent first), then the rest in catalogue order.
    public static func order(_ editors: [Editor], recent: [String]) -> [Editor] {
        let rank = Dictionary(recent.enumerated().map { ($1.lowercased(), $0) }, uniquingKeysWith: min)
        return editors.enumerated().sorted { a, b in
            switch (rank[a.element.bundleID.lowercased()], rank[b.element.bundleID.lowercased()]) {
            case let (x?, y?): return x < y
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return a.offset < b.offset
            }
        }.map(\.element)
    }
}
