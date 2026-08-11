// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "Fixture",
    platforms: [.macOS(.v10_15)],
    products: [.library(name: "Fixture", targets: ["Fixture"])],
    targets: [
        .target(name: "Fixture"),
        .testTarget(name: "FixtureTests", dependencies: ["Fixture"]),
    ]
)
