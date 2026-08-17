//
//  XCResultToolInvocationTests.swift
//
//  Which process a query actually spawns.
//
//  `xcrun` resolves a tool and execs it, so routing every query through it
//  costs a whole extra process — measured at ~7 ms per call, against ~28 ms
//  for the query itself. At one query per test case that is seconds of pure
//  overhead on a large bundle (`docs/reader-performance.md`).
//

import XCTest
@testable import XCTestHTMLReportCore

final class XCResultToolInvocationTests: XCTestCase {
    /// Resolved once, the tool is run directly and `xcrun` is not involved.
    func testResolvedToolIsInvokedDirectly() {
        let tool =
            URL(fileURLWithPath: "/Applications/Xcode.app/Contents/Developer/usr/bin/xcresulttool")

        let invocation = XCResultToolClient.invocation(resolvedTool: tool)

        XCTAssertEqual(invocation.executable, tool)
        XCTAssertTrue(
            invocation.leadingArguments.isEmpty,
            "Running the tool directly must not re-pass its own name as an argument"
        )
    }

    /// Unresolvable, it falls back to the original `xcrun` route rather than
    /// failing. `xcrun --find` can legitimately fail — no Xcode selected, a
    /// command line tools-only install — and that must degrade to slow, never
    /// to broken.
    func testUnresolvedToolFallsBackToXcrun() {
        let invocation = XCResultToolClient.invocation(resolvedTool: nil)

        XCTAssertEqual(invocation.executable.path, "/usr/bin/xcrun")
        XCTAssertEqual(invocation.leadingArguments, ["xcresulttool"])
    }

    /// The resolution itself works on this machine. Guards the case where
    /// `invocation` is correct but nothing ever resolves, which would silently
    /// leave every run on the slow path.
    func testToolResolvesOnThisMachine() throws {
        let resolved = try XCTUnwrap(
            XCResultToolClient.resolvedTool,
            "xcresulttool must resolve on a machine with Xcode selected"
        )

        XCTAssertEqual(resolved.lastPathComponent, "xcresulttool")
        XCTAssertTrue(
            FileManager.default.isExecutableFile(atPath: resolved.path),
            "\(resolved.path) is not executable"
        )
    }

    /// The direct route must answer exactly what the `xcrun` route answered.
    /// This is the guard on the whole change: identical bytes, or the speedup
    /// bought a different reader.
    func testDirectInvocationMatchesXcrunOutput() throws {
        let url = try XCTUnwrap(
            Bundle.testBundle.url(forResource: "SanityResults", withExtension: "xcresult")
        )
        let arguments = ["get", "test-results", "summary"]

        let direct = try XCResultToolClient(bundleURL: url).run(arguments)
        let viaXcrun = try Self.runViaXcrun(arguments, bundleURL: url)

        XCTAssertEqual(direct, viaXcrun)
    }

    // MARK: Private

    /// The pre-change invocation, spelled out so the comparison above is
    /// against the real `xcrun` route rather than against the code under test.
    private static func runViaXcrun(_ arguments: [String], bundleURL: URL) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["xcresulttool"] + arguments + [
            "--path", bundleURL.path,
            "--schema-version", XCResultToolClient.schemaVersion,
        ]
        let out = Pipe()
        process.standardOutput = out
        process.standardError = Pipe()
        try process.run()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return data
    }
}
