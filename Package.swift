// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SIV",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "SIV", targets: ["SIV"])
    ],
    targets: [
        .executableTarget(
            name: "SIV",
            path: "SIV",
            exclude: ["Info.plist", "Resources"],
            sources: [
                "App",
                "Models",
                "Services",
                "ViewModels",
                "Views",
                "Utilities"
            ]
        ),
        .testTarget(
            name: "SIVTests",
            dependencies: ["SIV"],
            path: "SIVTests"
        )
    ]
)

