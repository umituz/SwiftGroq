// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SwiftGroq",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SwiftGroq",
            targets: ["SwiftGroq"])
    ],
    targets: [
        .target(
            name: "SwiftGroq",
            dependencies: [],
            path: "Sources/SwiftGroq"
        ),
        .testTarget(
            name: "SwiftGroqTests",
            dependencies: ["SwiftGroq"],
            path: "Tests/SwiftGroqTests"
        )
    ]
)
