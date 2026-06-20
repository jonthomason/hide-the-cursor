// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "hide-the-cursor",
    platforms: [
        .macOS(.v12)
    ],
    targets: [
        // Core logic lives in a library so the argument parser is unit-testable.
        .target(
            name: "HideTheCursor"
        ),
        // Thin executable: just parses argv and hands off to the library.
        .executableTarget(
            name: "hide-the-cursor",
            dependencies: ["HideTheCursor"]
        ),
        .testTarget(
            name: "HideTheCursorTests",
            dependencies: ["HideTheCursor"]
        ),
    ]
)
