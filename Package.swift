// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClipScylf",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ClipScylf",
            path: "Sources/QuickDrop"
        )
    ]
)
