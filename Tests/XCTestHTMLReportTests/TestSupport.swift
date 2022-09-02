//
//  File.swift
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
    XCTAssertTrue(target.contains(substring), "String <\(target)> does not contain substring <\(substring)>", file: file, line: line)
}

func urlFromXCHtmlreportStdout(_ stdOut: String) -> URL? {
    let regex = try! NSRegularExpression(pattern: ".*successfully created at (.+)$", options: [])
    guard let match = regex.firstMatch(
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
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        guard let match = regex.firstMatch(
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

    /// Return content of the first int group in the pattern. Pattern is supposed to have a group of ints like:
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
        process.waitUntilExit()

        let dataOut = pipeOut.fileHandleForReading.readDataToEndOfFile()
        let outputOut = String(data: dataOut, encoding: .utf8)

        let dataErr = pipeErr.fileHandleForReading.readDataToEndOfFile()
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
            XCTAssertEqual(status, 0)
            #if !DEBUG // XCResultKit outputs non-fatals to stderr in debug mode
                XCTAssertEqual((maybeStdErr ?? "").isEmpty, true)
            #endif
            let stdOut = try XCTUnwrap(maybeStdOut)
            let htmlUrl = try XCTUnwrap(urlFromXCHtmlreportStdout(stdOut))

            let htmlString = try String(contentsOf: htmlUrl, encoding: .utf8)
            return try SwiftSoup.parse(htmlString)
        }
    }
}
