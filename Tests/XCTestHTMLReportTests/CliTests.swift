import class Foundation.Bundle
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

        for attempt in 1 ... 5 {
            let (status, _, maybeStdErr) = try xchtmlreportCmd(args: [retryResultsUrl.path])
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
        let defaultArgs = ["-r", testResultsUrl.path]
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
        let (status, maybeStdOut, _) = try xchtmlreportCmd(
            args: ["--lenient", testResultsUrl.path]
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

    /// A scratch directory unique to the calling test, removed when it ends.
    private func makeScratchDirectory(
        _ name: String = #function
    ) throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("xchr-\(name)-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock {
            // Restore write permission first: the unwritable-output test drops
            // it on a subdirectory, and removeItem cannot unlink through it.
            let contents = FileManager.default.enumerator(atPath: root.path)?
                .allObjects as? [String] ?? []
            for entry in contents {
                try? FileManager.default.setAttributes(
                    [.posixPermissions: 0o755],
                    ofItemAtPath: root.appendingPathComponent(entry).path
                )
            }
            try? FileManager.default.removeItem(at: root)
        }
        return root
    }

    /// #446: the tool used to render the whole report and only then fail on
    /// `write(toFile:)`, surfacing as `The file "index.html" doesn't exist.`
    /// A missing output directory is created, like every comparable CLI does.
    func testNonexistentNestedOutputDirectoryIsCreated() throws {
        let testResultsUrl = try XCTUnwrap(testResultsUrl)
        let output = try makeScratchDirectory()
            .appendingPathComponent("nested/report/dir")

        let (status, maybeStdOut, maybeStdErr) = try xchtmlreportCmd(
            args: ["--output", output.path, testResultsUrl.path]
        )

        XCTAssertEqual(
            status, 0,
            "exited \(status).\nstdout:\n\(maybeStdOut ?? "")\nstderr:\n\(maybeStdErr ?? "")"
        )
        XCTAssertTrue(
            FileManager.default
                .fileExists(atPath: output.appendingPathComponent("index.html").path),
            "index.html was not written to the created output directory"
        )
    }

    /// The other half of #446: when the directory genuinely cannot be created,
    /// say so — naming the path — and say it before minutes of parsing rather
    /// than after. This is a usage error (exit 64, the code every other
    /// `ValidationError` in this tool produces), never a report-degradation
    /// fault (exit 3).
    func testUnwritableOutputDirectoryFailsFastNamingThePath() throws {
        try XCTSkipIf(getuid() == 0, "root bypasses directory permissions")
        let testResultsUrl = try XCTUnwrap(testResultsUrl)

        let readOnly = try makeScratchDirectory().appendingPathComponent("read-only")
        try FileManager.default.createDirectory(
            at: readOnly,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o555]
        )
        let output = readOnly.appendingPathComponent("report")

        let (status, maybeStdOut, maybeStdErr) = try xchtmlreportCmd(
            args: ["--verbose", "--output", output.path, testResultsUrl.path]
        )

        XCTAssertEqual(
            status, 64,
            "An unusable --output is a usage error, not a degraded report (3)"
        )

        let stdErr = try XCTUnwrap(maybeStdErr)
        try XCTAssertContains(stdErr, "Could not create output directory")
        try XCTAssertContains(stdErr, output.path)

        // Fail *fast*: the old behaviour reached the write only after building
        // the report, so this must not have got as far as rendering.
        let stdOut = maybeStdOut ?? ""
        XCTAssertFalse(
            stdOut.contains("Building HTML"),
            "Rendering ran before the output directory was checked:\n\(stdOut)"
        )
        XCTAssertFalse(
            stdErr.contains("index.html"),
            "Still blaming index.html for a missing output directory:\n\(stdErr)"
        )
    }
}
