// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "XCTestHTMLReport",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v10_15),
    ],
    products: [
        .executable(name: "xchtmlreport", targets: ["XCTestHTMLReport"]),
        .library(name: "xchtmlreportcore", targets: ["XCTestHTMLReportCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/onevcat/Rainbow.git", .upToNextMajor(from: "4.2.1")),
        .package(url: "https://github.com/davidahouse/XCResultKit.git", from: "1.2.1"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.4.3"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "XCTestHTMLReport",
            dependencies: [
                "XCTestHTMLReportCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .target(
            name: "XCTestHTMLReportCore",
            dependencies: ["Rainbow", "XCResultKit"]
        ),
        .testTarget(
            name: "XCTestHTMLReportTests",
            dependencies: ["XCTestHTMLReport", "SwiftSoup"],
            exclude: ["Snapshots"],
            resources: [
                .process("Resources/TestResults.xcresult"),
                .process("Resources/RetryResults.xcresult"),
                .process("Resources/SanityResults.xcresult"),
                .process("Resources/differential-allowlist.json"),
            ]
        ),
    ]
)
