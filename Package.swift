// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SIV",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "SIV",
            targets: ["SIV"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "SIV",
            dependencies: [],
            path: "Sources/SIV"
        ),
        .testTarget(
            name: "SIVTests",
            dependencies: ["SIV"],
            path: "Tests/SIVTests"
        )
    ]
)
