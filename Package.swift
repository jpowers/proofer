// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Proofer",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Proofer", path: "Sources/Proofer")
    ]
)
