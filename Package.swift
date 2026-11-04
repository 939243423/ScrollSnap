// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ScrollSnap",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ScrollSnapCore",
            targets: ["ScrollSnapCore"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ScrollSnapCore",
            path: "Shared"
        ),
        .testTarget(
            name: "ScrollSnapCoreTests",
            dependencies: ["ScrollSnapCore"],
            path: "Tests/ScrollSnapCoreTests"
        )
    ]
)
