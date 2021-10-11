// swift-tools-version:5.4

import PackageDescription

let package = Package(
    name: "XCTestHTMLReport",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .executable(name: "xchtmlreport", targets: ["XCTestHTMLReport"]),
        .library(name: "xchtmlreportcore", targets: ["XCTestHTMLReportCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/onevcat/Rainbow.git", .upToNextMajor(from: "3.0.0")),
        .package(
            url: "https://github.com/davidahouse/XCResultKit.git", .upToNextMinor(from: "0.9.2")),
        .package(url: "https://github.com/nacho4d/NDHpple.git", .upToNextMajor(from: "2.0.1")),
        .package(
            url: "https://github.com/apple/swift-argument-parser.git", .upToNextMajor(from: "1.0.0")
        ),
    ],
    targets: [
        .executableTarget(
            name: "XCTestHTMLReport",
            dependencies: [
                "XCTestHTMLReportCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            resources: [.process("Resources")]
        ),
        .target(
            name: "XCTestHTMLReportCore",
            dependencies: ["Rainbow", "XCResultKit"],
            exclude: ["HTML"]),  // ignore HTML directory resources. They are already imported as static strings.
        .testTarget(
            name: "XCTestHTMLReportTests",
            dependencies: ["XCTestHTMLReport", "NDHpple"],
            resources: [.copy("TestResults.xcresult")]),
    ]
)
