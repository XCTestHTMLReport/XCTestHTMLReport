//
//  VisualFixtureDumpTests.swift
//
//  Writes the synthetic render to $XCHR_VISUAL_DIR for the Playwright suite.
//  Skipped unless the variable is set, exactly like BaselineCaptureTests, so a
//  normal `swift test` neither writes files nor slows down.
//

import XCTest
@testable import XCTestHTMLReportCore

final class VisualFixtureDumpTests: XCTestCase {
    func testDumpSyntheticRender() throws {
        guard let dir = ProcessInfo.processInfo.environment["XCHR_VISUAL_DIR"] else {
            throw XCTSkip("Set XCHR_VISUAL_DIR to dump the visual fixture")
        }
        try FileManager.default.createDirectory(
            atPath: dir, withIntermediateDirectories: true
        )

        for (mode, name) in [(Summary.RenderingMode.linking, "report"),
                             (Summary.RenderingMode.inline, "report-inline")]
        {
            let html = Summary(
                parsedRuns: [SyntheticResult.parsedRun],
                payloads: SyntheticResult.payloads,
                renderingMode: mode,
                downsizeImagesEnabled: false,
                downsizeScaleFactor: 0.5
            ).generatedHtmlReport()

            let path = "\(dir)/\(name).html"
            try html.write(toFile: path, atomically: true, encoding: .utf8)

            // A zero-byte dump would let the Playwright suite pass vacuously.
            let written = try XCTUnwrap(
                FileManager.default.contents(atPath: path),
                "Dump produced no file at \(path)"
            )
            XCTAssertGreaterThan(written.count, 1000, "\(name).html is suspiciously small")
        }
    }
}
