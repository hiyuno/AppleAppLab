// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AppleAppLabUI",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "AppleAppLabUI", targets: ["AppleAppLabUI"]),
        // Brand package for web-lab (contract: web-lab docs/app-brand-package.md). macOS tool, not linked into apps.
        .executable(name: "lab-brand-package", targets: ["lab-brand-package"])
    ],
    targets: [
        .target(name: "AppleAppLabUI", swiftSettings: [.swiftLanguageMode(.v6)]),
        .target(name: "LabBrandPackage", dependencies: ["AppleAppLabUI"], swiftSettings: [.swiftLanguageMode(.v6)]),
        .executableTarget(name: "lab-brand-package", dependencies: ["LabBrandPackage"], swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(name: "AppleAppLabUITests", dependencies: ["AppleAppLabUI"]),
        .testTarget(name: "LabBrandPackageTests", dependencies: ["LabBrandPackage", "AppleAppLabUI"])
    ]
)
