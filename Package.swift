// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "SwiftWebServer",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
        .visionOS(.v1),
    ],
    products: [
        .library(
            name: "SwiftWebServer",
            targets: ["SwiftWebServer"]
        ),
    ],
    targets: [
        .target(
            name: "SwiftWebServer",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "SwiftWebServerTests",
            dependencies: ["SwiftWebServer"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "SwiftWebServerXCTests",
            dependencies: ["SwiftWebServer"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
