// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OakSwiftUI",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "OakSwiftUI", type: .dynamic, targets: ["OakSwiftUI"])
    ],
    targets: [
        .target(
            name: "OakSwiftUI",
            path: "Sources/OakSwiftUI"
        ),
        .testTarget(
            name: "OakSwiftUITests",
            dependencies: ["OakSwiftUI"],
            path: "Tests/OakSwiftUITests"
        )
    ]
)
