import class Foundation.Bundle
import class Foundation.FileManager
import struct Foundation.URL
import struct Foundation.UUID
import SwiftSoup
import XCTest

final class CliTests: XCTestCase {
    var testResultsUrl: URL? {
        Bundle.testBundle
            .url(forResource: "TestResults", withExtension: "xcresult")
    }

    var retryResultsUrl: URL? {
        Bundle.testBundle
            .url(forResource: "RetryResults", withExtension: "xcresult")
    }

    /// `RetryResults.xcresult` contains two attachments that share one payload
    /// ref (the screen recording of a retried test). Exporting them
    /// concurrently used to race, intermittently losing the file and reporting
    /// a spurious `unresolvedAttachment` — so this bundle exited 3 on some runs
    /// and 0 on others. Repeat the run so a reintroduced race is caught rather
    /// than sampled away.
    func testRetryBundleWithSharedPayloadRefsExitsZero() throws {
        guard let retryResultsUrl else {
            throw XCTSkip("RetryResults.xcresult not found, this likely means Xcode < 13.0")
        }
        let outputDirectory = try makeTemporaryOutputDirectory()

        for attempt in 1 ... 5 {
            let (status, _, maybeStdErr) = try xchtmlreportCmd(
                args: [retryResultsUrl.path, "-o", outputDirectory.path]
            )
            XCTAssertEqual(
                status, 0,
                "attempt \(attempt) exited \(status). stderr:\n\(maybeStdErr ?? "")"
            )
        }
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
        try assertAttachmentsExist()
    }

    func testDownsizedAttachmentsExist() throws {
        try assertAttachmentsExist(extraArgs: ["-z"])
    }

    func assertAttachmentsExist(extraArgs: [String] = []) throws {
        let testResultsUrl = try XCTUnwrap(testResultsUrl)
        let outputDirectory = try makeTemporaryOutputDirectory()

        let defaultArgs = ["-r", testResultsUrl.path, "-o", outputDirectory.path]
        let document = try parseReportDocument(xchtmlreportArgs: defaultArgs + extraArgs)
        let reportDir = testResultsUrl.deletingLastPathComponent()

        // Restored by #393. This was commented out when Xcode 15 began attaching
        // videos by default, which left every image path in the tool -- the
        // `screenshot` CSS class, screenshot.html, and the `-z` downsizing
        // branch -- with no coverage at all. `FirstSuite.testAttachScreenshot`
        // now attaches a real `public.png`, so these assertions have something
        // to bite on. If this stops finding images, the fixture lost its
        // screenshot; do not comment it out again.
        try XCTContext.runActivity(named: "Image attachments exist") { _ in
            let imgTags = try document
                .select("img.screenshot, img.screenshot-flow, img.screenshot-tail")
            XCTAssertFalse(
                imgTags.isEmpty(),
                "No image attachments rendered. Expected at least the screenshot "
                    + "attached by FirstSuite.testAttachScreenshot."
            )

            try imgTags.forEach { img in
                let src = try img.attr("src")
                XCTAssertTrue(
                    src.starts(with: "TestResults.xcresult/"),
                    "Unexpected image src: \(src)"
                )
                let attachmentUrl = try XCTUnwrap(URL(string: src, relativeTo: reportDir))
                XCTAssertNoThrow(
                    try attachmentUrl.checkResourceIsReachable(),
                    "Image referenced but not exported: \(src)"
                )
            }
        }

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

    func testLenientFlagIsAccepted() throws {
        let testResultsUrl = try XCTUnwrap(testResultsUrl)
        let outputDirectory = try makeTemporaryOutputDirectory()
        let (status, maybeStdOut, _) = try xchtmlreportCmd(
            args: ["--lenient", testResultsUrl.path, "-o", outputDirectory.path]
        )

        // --lenient never fails on faults, so a readable bundle always exits 0.
        XCTAssertEqual(status, 0)
        try XCTAssertContains(try XCTUnwrap(maybeStdOut), "successfully created")
    }

    func testUnreadableBundleExitsNonZeroWithFaultSummary() throws {
        let bogus = NSTemporaryDirectory() + "/DoesNotExist.xcresult"
        try? FileManager.default.createDirectory(
            atPath: bogus, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(atPath: bogus) }

        let (status, maybeStdOut, maybeStdErr) = try xchtmlreportCmd(args: [bogus])

        XCTAssertEqual(status, 3, "Faults must produce exit code 3")
        let combined = (maybeStdOut ?? "") + (maybeStdErr ?? "")
        try XCTAssertContains(combined, "missingInvocationRecord")
    }

    func testUnreadableBundleExitsZeroUnderLenient() throws {
        let bogus = NSTemporaryDirectory() + "/DoesNotExistLenient.xcresult"
        try? FileManager.default.createDirectory(
            atPath: bogus, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(atPath: bogus) }

        let (status, _, _) = try xchtmlreportCmd(args: ["--lenient", bogus])

        XCTAssertEqual(status, 0, "--lenient restores 2.x exit behaviour")
    }

    private func makeTemporaryOutputDirectory() throws -> URL {
        let outputDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )
        addTeardownBlock {
            try? FileManager.default.removeItem(at: outputDirectory)
        }
        return outputDirectory
    }
}
