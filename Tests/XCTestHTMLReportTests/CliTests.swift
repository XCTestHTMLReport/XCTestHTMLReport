import class Foundation.Bundle
import SwiftSoup
import XCTest

final class CliTests: XCTestCase {
    var testResultsUrl: URL? {
        Bundle.testBundle
            .url(forResource: "TestResults", withExtension: "xcresult")
    }

    func testNoArgs() throws {
        let (status, maybeStdOut, maybeStdErr) = try xchtmlreportCmd(args: [])

        XCTAssertEqual(status, 64)
        XCTAssertEqual(maybeStdOut?.isEmpty, true)
        let stdErr = try XCTUnwrap(maybeStdErr)
        try XCTAssertContains(
            stdErr,
            "Error: Bundles must be provided either by args or the -r option"
        )
    }

    func testAttachmentsExist() throws {
        try _testAttachmentsExist()
    }

    func testDownsizedAttachmentsExist() throws {
        try _testAttachmentsExist(extraArgs: ["-z"])
    }

    func _testAttachmentsExist(extraArgs: [String] = []) throws {
        let testResultsUrl = try XCTUnwrap(testResultsUrl)
        let defaultArgs = ["-r", testResultsUrl.path]
        let document = try parseReportDocument(xchtmlreportArgs: defaultArgs + extraArgs)
        let reportDir = testResultsUrl.deletingLastPathComponent()

        // Remove this logic for now since Xcode 15 attaches videos by default.
        // We'll want to create a separate test result specifically with screenshots enabled
//        try XCTContext.runActivity(named: "Image attachments exist") { _ in
//            let imgTags = try document.select("img.screenshot, img.screenshot-flow")
//            XCTAssertFalse(imgTags.isEmpty())
//
//            try imgTags.forEach { img in
//                let src = try img.attr("src")
//                XCTAssertTrue(src.starts(with: "TestResults.xcresult/"))
//                let attachmentUrl = try XCTUnwrap(URL(string: src, relativeTo: reportDir))
//                XCTAssertNoThrow(try attachmentUrl.checkResourceIsReachable())
//            }
//        }

        try XCTContext.runActivity(named: "Other attachments exist", block: { _ in
            let spanTags = try document.select("span.icon.preview-icon")
            XCTAssertFalse(spanTags.isEmpty())

            try spanTags.forEach { span in
                let onClick = try span.attr("onclick")
                guard onClick.starts(with: "showText") else {
                    return
                }

                let data = try span.attr("data")
                XCTAssertTrue(data.starts(with: "TestResults.xcresult/"))
                let attachmentUrl = try XCTUnwrap(URL(string: data, relativeTo: reportDir))
                XCTAssertNoThrow(try attachmentUrl.checkResourceIsReachable())
            }
        })
    }
}
