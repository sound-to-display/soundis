// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Soundis",
    platforms: [.macOS("26.0")],
    targets: [
        .executableTarget(
            name: "Soundis",
            path: "Sources/Soundis",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
