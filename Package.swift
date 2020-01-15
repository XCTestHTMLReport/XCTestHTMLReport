// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "XCTestHTMLReport",
    products: [
        .executable(name: "xchtmlreport", targets: ["XCTestHTMLReport"])
    ],
    dependencies: [
         .package(url: "https://github.com/onevcat/Rainbow.git", from: "3.0.0"),
         .package(url: "https://github.com/davidahouse/XCResultKit.git", from: "0.5.3")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "XCTestHTMLReport",
            dependencies: ["Rainbow", "XCResultKit"]),
        .testTarget(
            name: "XCTestHTMLReportTests",
            dependencies: ["XCTestHTMLReport"]),
    ]
)
