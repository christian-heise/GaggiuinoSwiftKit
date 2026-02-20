// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GaggiuinoSwiftKit",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .watchOS(.v11),
        .tvOS(.v18),
        .visionOS(.v2)
    ],
    products: [
        .library(
            name: "GaggiuinoSwiftKit",
            targets: ["GaggiuinoSwiftKit"]
        ),
    ],
    targets: [
        .target(
            name: "GaggiuinoSwiftKit",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "GaggiuinoSwiftKitTests",
            dependencies: ["GaggiuinoSwiftKit"],
            exclude: ["README.md"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        )
    ]
)
