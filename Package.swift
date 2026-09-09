// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Qota",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Qota",
            path: "Qota"
        )
    ]
)
