//
//  SummarySeamTests.swift
//

import XCTest
@testable import XCTestHTMLReportCore

final class SummarySeamTests: XCTestCase {
    private func summary(renderingMode: Summary.RenderingMode = .linking) -> Summary {
        Summary(
            parsedRuns: [SyntheticResult.parsedRun],
            payloads: SyntheticResult.payloads,
            renderingMode: renderingMode,
            downsizeImagesEnabled: false,
            downsizeScaleFactor: 0.5
        )
    }

    func testRendersAFullPageWithoutAnXcresult() {
        let html = summary().generatedHtmlReport()
        XCTAssertTrue(html.hasPrefix("<!doctype html>"), "must render the index template")
        XCTAssertTrue(html.contains("SyntheticSuite"), "must render the fixture's group")
        XCTAssertTrue(html.contains(":root"), "must carry the token layer")
        XCTAssertFalse(
            html.contains("id=\"logs-iframe\" src=\"\""),
            "the run's log reference must resolve to something, not degrade to an empty iframe"
        )
    }

    /// Distinct from `testRendersAFullPageWithoutAnXcresult`: that test proves
    /// a log *reference* made it into the page under `.linking`, where the
    /// iframe source is only a relative file name. This proves the log
    /// *bytes* the fixture provides genuinely reach the rendered HTML, which
    /// requires `.inline`, the one mode where `RenderingContent.data` embeds
    /// them directly as the iframe's `data:` URI rather than pointing at a
    /// file nothing in this synthetic pipeline ever writes.
    func testInlineRenderingEmbedsTheActualLogBytes() {
        let html = summary(renderingMode: .inline).generatedHtmlReport()
        let expectedDataURI = "data:text/plain;base64,"
            + StubPayloadProvider.logText.base64EncodedString()
        XCTAssertTrue(
            html.contains(expectedDataURI),
            "the fixture's log bytes must be embedded verbatim, not merely referenced"
        )
    }

    func testRendersNoFaults() {
        XCTAssertTrue(
            summary().faults.isEmpty,
            "A complete synthetic tree must not degrade the report"
        )
    }

    func testIsDeterministic() {
        XCTAssertEqual(
            summary().generatedHtmlReport(),
            summary().generatedHtmlReport(),
            "Two renders of one fixture must agree byte for byte"
        )
    }
}
