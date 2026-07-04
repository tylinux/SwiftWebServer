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
        .library(
            name: "SwiftWebServerWebUpload",
            targets: ["SwiftWebServerWebUpload"]
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
        .target(
            name: "SwiftWebServerWebUpload",
            dependencies: ["SwiftWebServer"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .target(
            name: "SwiftWebServerDocc",
            dependencies: ["SwiftWebServer"],
            path: "Sources/SwiftWebServerDocc",
            resources: [
                .process("SwiftWebServer.docc")
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
            name: "SwiftWebServerWebUploadTests",
            dependencies: ["SwiftWebServerWebUpload"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
