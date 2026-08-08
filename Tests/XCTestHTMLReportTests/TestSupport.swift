//
//  TestSupport.swift
//
//
//  Created by Guillermo Ignacio Enriquez Gutierrez on 2020/09/22.
//

import class Foundation.Bundle
import SwiftSoup
import XCTest

func XCTAssertContains(
    _ targetCosure: @autoclosure () throws -> String,
    _ substringClosure: @autoclosure () -> String,
    file: StaticString = #filePath,
    line: UInt = #line
) throws {
    let target = try targetCosure()
    let substring = substringClosure()
    XCTAssertTrue(
        target.contains(substring),
        "String <\(target)> does not contain substring <\(substring)>",
        file: file,
        line: line
    )
}

func urlFromXCHtmlreportStdout(_ stdOut: String) -> URL? {
    let regex = try? NSRegularExpression(pattern: ".*successfully created at (.+)$", options: [])
    guard let match = regex?.firstMatch(
        in: stdOut,
        options: [],
        range: NSRange(location: 0, length: stdOut.count)
    ) else {
        return nil
    }
    let htmlPath = (stdOut as NSString).substring(with: match.range(at: 1))
    return URL(fileURLWithPath: htmlPath)
}

extension String {
    /// Return content of the firs group in the pattern. Pattern is supposed to have a group like:
    /// `"What ever here is ok(.+)Also here. anything is ok."`
    func groupMatch(_ pattern: String) -> String? {
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        guard let match = regex?.firstMatch(
            in: self,
            options: [],
            range: NSRange(location: 0, length: count)
        ) else {
            return nil
        }
        if match.numberOfRanges > 0 {
            return (self as NSString).substring(with: match.range(at: 1))
        }
        return (self as NSString).substring(with: match.range(at: 0))
    }

    /// Return content of the first int group in the pattern. Pattern is supposed to have a group of
    /// ints like:
    /// `"What ever here is ok(\\d+)Also here. anything is ok."`
    func intGroupMatch(_ pattern: String) -> Int? {
        let str = groupMatch(pattern) ?? ""
        return Int(str)
    }
}

extension Bundle {
    static let testBundle: Bundle = {
        #if compiler(>=5.7)
            // Fixed in Xcode 14 beta 4
            return Bundle.module
        #else
            // This is needed because `Bundle.module` will not work in tests.
            // https://roundwallsoftware.com/swift-package-testing/
            let baseBundle = Bundle(for: CoreTests.classForCoder())
            return Bundle(
                path: baseBundle
                    .bundlePath + "/../XCTestHTMLReport_XCTestHTMLReportTests.bundle"
            )!
        #endif
    }()
}

extension XCTestCase {
    /// Returns path to the built products directory.
    var productsDirectory: URL {
        #if os(macOS)
            for bundle in Bundle.allBundles where bundle.bundlePath.hasSuffix(".xctest") {
                return bundle.bundleURL.deletingLastPathComponent()
            }
            fatalError("couldn't find the products directory")
        #else
            return Bundle.main.bundleURL
        #endif
    }

    /// Helper function to execute xchtmlreport command
    /// Int32 is status
    /// String? is string std out
    /// String? is string std err
    func xchtmlreportCmd(args: [String]) throws -> (Int32, String?, String?) {
        let binaryUrl = productsDirectory.appendingPathComponent("xchtmlreport")

        let process = Process()
        process.executableURL = binaryUrl
        process.arguments = args

        let pipeOut = Pipe()
        process.standardOutput = pipeOut

        let pipeErr = Pipe()
        process.standardError = pipeErr

        try process.run()

        // Drain both pipes concurrently, and before waiting on the process.
        // Waiting first deadlocks as soon as either stream outgrows its pipe
        // buffer: the child blocks in write() and this thread never gets to the
        // read. xchtmlreport passes its own stdout to the `xcresulttool`
        // processes it spawns, so the amount at stake is not under its control.
        var dataErr = Data()
        let errorDrained = DispatchGroup()
        errorDrained.enter()
        DispatchQueue.global().async {
            dataErr = pipeErr.fileHandleForReading.readDataToEndOfFile()
            errorDrained.leave()
        }
        let dataOut = pipeOut.fileHandleForReading.readDataToEndOfFile()
        errorDrained.wait()

        process.waitUntilExit()

        let outputOut = String(data: dataOut, encoding: .utf8)
        let outputErr = String(data: dataErr, encoding: .utf8)

        return (process.terminationStatus, outputOut, outputErr)
    }

    func parseReportDocument(xchtmlreportArgs: [String]) throws -> Document {
        try XCTContext.runActivity(named: #function) { _ in
            let (
                status,
                maybeStdOut,
                maybeStdErr
            ) = try xchtmlreportCmd(args: xchtmlreportArgs)

            // Exit 3 means the tool collected faults. Previously this harness
            // only checked stderr, and only in release builds — so `swift test`
            // (always debug) could never see degradation at all.
            let stdOut = try XCTUnwrap(maybeStdOut)
            let stdErr = maybeStdErr ?? ""
            XCTAssertEqual(
                status, 0,
                "xchtmlreport exited \(status).\nstdout:\n\(stdOut)\nstderr:\n\(stdErr)"
            )

            // Degradation is reported through `Logger.warning`, which writes to
            // stderr. Check both streams so this keeps working whichever stream
            // the diagnostics end up on.
            let combinedOutput = stdOut + stdErr
            XCTAssertFalse(
                combinedOutput.contains("Report is degraded"),
                "Report was degraded:\n\(combinedOutput)"
            )

            let htmlUrl = try XCTUnwrap(urlFromXCHtmlreportStdout(stdOut))
            let htmlString = try String(contentsOf: htmlUrl, encoding: .utf8)
            return try SwiftSoup.parse(htmlString)
        }
    }
}
