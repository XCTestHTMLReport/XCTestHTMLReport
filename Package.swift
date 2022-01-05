// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "XCTestHTMLReport",
    platforms: [
        .macOS(.v10_15),
    ],
    products: [
        .executable(name: "xchtmlreport", targets: ["XCTestHTMLReport"]),
        .library(name: "xchtmlreportcore", targets: ["XCTestHTMLReportCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/onevcat/Rainbow.git", .upToNextMajor(from: "3.0.0")),
        .package(url: "https://github.com/davidahouse/XCResultKit.git", .upToNextMinor(from: "0.9.3")),
        .package(url: "https://github.com/nacho4d/NDHpple.git", .upToNextMajor(from: "2.0.1")),
    ],
    targets: [
        .target(
            name: "XCTestHTMLReport",
            dependencies: ["XCTestHTMLReportCore"]),
        .target(
            name: "XCTestHTMLReportCore",
            dependencies: ["Rainbow", "XCResultKit"],
            exclude: ["HTML"]), // ignore HTML directory resources. They are already imported as static strings.
        .testTarget(
            name: "XCTestHTMLReportTests",
            dependencies: ["XCTestHTMLReport", "NDHpple"],
            resources: [
                .copy("TestResults.xcresult"),
                .copy("RetryResults.xcresult"),
            ]
        )
    ]
)
