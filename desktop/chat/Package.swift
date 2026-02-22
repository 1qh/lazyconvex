// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "chat-desktop",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../shared"),
        .package(url: "https://github.com/stackotter/swift-cross-ui.git", branch: "main"),
    ],
    targets: [
        .executableTarget(name: "Chat", dependencies: [
            .product(name: "DesktopShared", package: "shared"),
            .product(name: "SwiftCrossUI", package: "swift-cross-ui"),
            .product(name: "DefaultBackend", package: "swift-cross-ui"),
        ], path: "Sources"),
        .testTarget(name: "ChatTests", dependencies: ["Chat"], path: "Tests"),
    ]
)
