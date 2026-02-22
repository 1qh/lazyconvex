// swift-tools-version: 6.1
import PackageDescription

internal let package = Package(
    name: "convex-shared",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ConvexShared", type: .dynamic, targets: ["ConvexShared"]),
    ],
    dependencies: [
        .package(url: "https://source.skip.tools/skip.git", from: "1.7.2"),
        .package(url: "https://source.skip.tools/skip-foundation.git", from: "1.0.0"),
        .package(url: "https://source.skip.tools/skip-ui.git", from: "1.46.0"),
        .package(url: "https://source.skip.tools/skip-keychain.git", from: "0.3.2"),
        .package(url: "https://source.skip.tools/skip-authentication-services.git", from: "0.0.2"),
        .package(url: "https://source.skip.tools/skip-kit.git", from: "0.6.1"),
        .package(url: "https://github.com/get-convex/convex-swift.git", from: "0.4.0"),
    ],
    targets: [
        .target(name: "ConvexShared", dependencies: [
            .product(name: "SkipFoundation", package: "skip-foundation"),
            .product(name: "SkipUI", package: "skip-ui"),
            .product(name: "SkipKeychain", package: "skip-keychain"),
            .product(name: "SkipAuthenticationServices", package: "skip-authentication-services"),
            .product(name: "SkipKit", package: "skip-kit"),
            .product(
                name: "ConvexMobile",
                package: "convex-swift",
                condition: .when(platforms: [.iOS, .macOS])
            ),
        ], plugins: [.plugin(name: "skipstone", package: "skip")]),
        .testTarget(name: "ConvexSharedTests", dependencies: [
            "ConvexShared",
            .product(name: "SkipTest", package: "skip"),
        ], plugins: [.plugin(name: "skipstone", package: "skip")]),
    ]
)
