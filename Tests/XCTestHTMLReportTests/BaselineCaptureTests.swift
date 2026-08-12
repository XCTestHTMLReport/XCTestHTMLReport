//
//  BaselineCaptureTests.swift
//
//  Writes renders of every fixture to $XCHR_BASELINE_DIR.
//  Fixtures are regenerated on each `prepareTestResults.sh` run, so a golden
//  file cannot be checked in; capture before a refactor and again after,
//  against one fixture generation, then diff the two directories.
//
//  Renders are captured verbatim. Identifiers are deterministic per structural
//  path (#430), so an identifier that moved is a real finding about the
//  refactor, not noise to normalize away.
//

import XCTest
@testable import XCTestHTMLReportCore

final class BaselineCaptureTests: XCTestCase {
    func testCaptureRawRenders() throws {
        guard let dir = ProcessInfo.processInfo.environment["XCHR_BASELINE_DIR"] else {
            throw XCTSkip("Set XCHR_BASELINE_DIR to capture baseline renders")
        }
        try FileManager.default.createDirectory(
            atPath: dir, withIntermediateDirectories: true
        )

        let resources = ["TestResults", "SanityResults", "RetryResults"]
        for resource in resources {
            // Deliberately not `continue`: a skipped fixture would produce a
            // partial baseline, and Task 5a's `diff -r` reports two partial
            // directories as identical. Fail here instead.
            let url = try XCTUnwrap(
                Bundle.testBundle.url(forResource: resource, withExtension: "xcresult"),
                "Fixture \(resource).xcresult is missing — run ./prepareTestResults.sh"
            )
            let html = Summary(
                resultPaths: [url.path],
                renderingMode: .linking,
                downsizeImagesEnabled: false,
                downsizeScaleFactor: 0.5
            ).generatedHtmlReport()
            let path = "\(dir)/\(resource).html"
            try html.write(
                toFile: path, atomically: true, encoding: .utf8
            )
            let written = try XCTUnwrap(
                FileManager.default.contents(atPath: path)
            )
            XCTAssertFalse(written.isEmpty, "\(resource) captured an empty baseline")
        }

        let captured = try FileManager.default
            .contentsOfDirectory(atPath: dir)
            .filter { $0.hasSuffix(".html") }
        XCTAssertEqual(
            Set(captured), Set(resources.map { "\($0).html" }),
            "Baseline must contain exactly one file per fixture"
        )
    }
}
