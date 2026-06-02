// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Downbar",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Downbar",
            path: "Sources/Downbar",
            resources: [
                .process("Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "DownbarTests",
            dependencies: ["Downbar"]
        )
    ]
)
