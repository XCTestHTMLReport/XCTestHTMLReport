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
    /// One file the Playwright suite reads.
    private struct Fixture {
        let name: String
        let mode: Summary.RenderingMode
        let runs: [ParsedRun]
    }

    func testDumpSyntheticRender() throws {
        guard let dir = ProcessInfo.processInfo.environment["XCHR_VISUAL_DIR"] else {
            throw XCTSkip("Set XCHR_VISUAL_DIR to dump the visual fixture")
        }
        try FileManager.default.createDirectory(
            atPath: dir, withIntermediateDirectories: true
        )

        // `report-multi` is the third since A3a (#439): the per-view shell's
        // navigation claims — one picker switching both views, a digest jump
        // crossing destinations — are only assertable on a report that holds
        // more than one run, and the other two dumps deliberately hold one.
        let single = [SyntheticResult.parsedRun]
        let fixtures = [
            Fixture(name: "report", mode: .linking, runs: single),
            Fixture(name: "report-inline", mode: .inline, runs: single),
            Fixture(
                name: "report-multi",
                mode: .linking,
                runs: single + [SyntheticResult.secondParsedRun]
            ),
        ]

        for fixture in fixtures {
            let (name, mode) = (fixture.name, fixture.mode)
            let html = Summary(
                parsedRuns: fixture.runs,
                payloads: SyntheticResult.payloads,
                renderingMode: mode,
                downsizeImagesEnabled: false,
                downsizeScaleFactor: 0.5,
                bundleNames: ["Synthetic"]
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
