// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "QuickDrop",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "QuickDrop",
            path: "Sources/QuickDrop"
        )
    ]
)
