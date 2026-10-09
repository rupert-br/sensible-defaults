// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SensibleDefaults",
    platforms: [.macOS(.v13)],
    targets: [
        // Platform-neutral decision logic; no AppKit.
        .target(name: "SensibleCore"),
        .executableTarget(name: "SensibleDefaults", dependencies: ["SensibleCore"]),
        .testTarget(name: "SensibleCoreTests", dependencies: ["SensibleCore"]),
    ]
)
