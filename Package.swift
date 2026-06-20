// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "hide-the-cursor",
    platforms: [
        .macOS(.v12)
    ],
    targets: [
        .executableTarget(
            name: "hide-the-cursor"
        ),
        .testTarget(
            name: "hide-the-cursor-tests",
            dependencies: ["hide-the-cursor"]
        ),
    ]
)
