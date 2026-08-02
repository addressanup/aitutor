// swift-tools-version: 6.2
import PackageDescription

// The Tutor shell — native macOS organs behind an IPC boundary. One target per
// organ so they grow independently; spikes REUSE AXBridge, never copy it.
// Language mode 6 (strict concurrency) throughout; app/overlay compile with
// default MainActor isolation, systems targets nonisolated.
let package = Package(
    name: "TutorShell",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "Tutor", targets: ["TutorShellApp"]),
        .executable(name: "axprobe", targets: ["AXProbe"]),
        .executable(name: "snapshot-spike", targets: ["SnapshotSpike"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.4.0"),
    ],
    targets: [
        .target(name: "ShellProtocol"),
        .target(name: "AXBridge"),
        .target(name: "EventTapGuard"),
        .target(name: "Permissions"),
        .target(
            name: "Overlay",
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .target(name: "CapturePipeline"),
        .target(name: "VoiceIO"),
        .target(name: "IPCServer", dependencies: ["ShellProtocol"]),
        .executableTarget(
            name: "TutorShellApp",
            dependencies: ["ShellProtocol", "IPCServer", "Permissions", "Overlay", "AXBridge", "EventTapGuard", "CapturePipeline", "VoiceIO"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .executableTarget(
            name: "AXProbe",
            dependencies: ["AXBridge", .product(name: "ArgumentParser", package: "swift-argument-parser")]
        ),
        .executableTarget(
            name: "SnapshotSpike",
            dependencies: ["AXBridge", "EventTapGuard", .product(name: "ArgumentParser", package: "swift-argument-parser")]
        ),
        .testTarget(name: "ShellProtocolTests", dependencies: ["ShellProtocol"]),
    ]
)
