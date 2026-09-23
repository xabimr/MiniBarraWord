// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "MiniBarra",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MiniBarra",
            path: "Sources/MiniBarra"
        )
    ]
)
