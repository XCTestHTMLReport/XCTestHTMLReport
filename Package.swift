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
        .package(url: "https://github.com/onevcat/Rainbow.git", .upToNextMajor(from: "3.0.0")),
        .package(url: "https://github.com/davidahouse/XCResultKit.git", from: "1.2.0"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.4.3"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
        .package(url: "https://github.com/nicklockwood/SwiftFormat", from: "0.50.4"),
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
            dependencies: ["Rainbow", "XCResultKit"],
            exclude: ["HTML"]
        ), // ignore HTML directory resources. They are already imported as static strings.
        .testTarget(
            name: "XCTestHTMLReportTests",
            dependencies: ["XCTestHTMLReport", "SwiftSoup"],
            resources: [
                .process("Resources/TestResults.xcresult"),
                .process("Resources/RetryResults.xcresult"),
                .process("Resources/SanityResults.xcresult"),
            ]
        ),
    ]
)
