// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CommandInput",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CommandInputCore", targets: ["CommandInputCore"]),
    ],
    targets: [
        .target(
            name: "CommandInputCore",
            path: "Sources/Core"
        ),
        .testTarget(
            name: "CommandInputCoreTests",
            dependencies: ["CommandInputCore"],
            path: "Tests/CoreTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
