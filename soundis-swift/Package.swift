// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Soundis",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Soundis",
            path: "Sources/Soundis",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
