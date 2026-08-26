// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AppleAppLabUI",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AppleAppLabUI", targets: ["AppleAppLabUI"])
    ],
    targets: [
        .target(name: "AppleAppLabUI", swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(name: "AppleAppLabUITests", dependencies: ["AppleAppLabUI"])
    ]
)
