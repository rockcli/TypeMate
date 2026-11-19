// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TypeMate",
    platforms: [
        .macOS(.v15)
    ],
    targets: [
        .executableTarget(
            name: "TypeMate",
            path: "Sources/TypeMate"
        )
    ]
)
