// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "desktop-shared",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DesktopShared", targets: ["DesktopShared"]),
    ],
    dependencies: [
        .package(path: "../../swift-core"),
    ],
    targets: [
        .target(name: "DesktopShared", dependencies: [
            .product(name: "ConvexCore", package: "swift-core"),
        ]),
        .testTarget(name: "DesktopSharedTests", dependencies: ["DesktopShared"]),
    ]
)
