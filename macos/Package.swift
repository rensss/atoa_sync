// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AndroidSyncMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "AndroidSyncCore", targets: ["AndroidSyncCore"]),
        .executable(name: "AndroidSyncMac", targets: ["AndroidSyncMac"])
    ],
    targets: [
        .target(
            name: "AndroidSyncCore",
            path: "Sources/AndroidSyncCore"
        ),
        .executableTarget(
            name: "AndroidSyncMac",
            dependencies: ["AndroidSyncCore"],
            path: "Sources/AndroidSyncMac"
        ),
        .testTarget(
            name: "AndroidSyncCoreTests",
            dependencies: ["AndroidSyncCore"],
            path: "Tests/AndroidSyncCoreTests"
        )
    ]
)
