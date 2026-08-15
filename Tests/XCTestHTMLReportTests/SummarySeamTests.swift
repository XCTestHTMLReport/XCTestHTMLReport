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
            downsizeScaleFactor: 0.5,
            bundleNames: ["Synthetic"]
        )
    }

    func testRendersAFullPageWithoutAnXcresult() {
        let html = summary().generatedHtmlReport()
        XCTAssertTrue(html.hasPrefix("<!doctype html>"), "must render the index template")
        XCTAssertTrue(html.contains("SyntheticSuite"), "must render the fixture's group")
        XCTAssertTrue(html.contains(":root"), "must carry the token layer")
        // A3b (#439) renders the log in the page, so the check that its
        // reference resolved is that the `<pre>` holds something rather than
        // that an iframe has a non-empty `src`. Same assertion, against the
        // element the log actually lands in now.
        XCTAssertFalse(
            html.contains("<pre class=\"log-body\" tabindex=\"0\"></pre>"),
            "the run's log reference must resolve to something, not degrade to an empty pane"
        )
    }

    /// Distinct from `testRendersAFullPageWithoutAnXcresult`: that test proves
    /// the log pane is not empty. This proves the *bytes* the fixture provides
    /// are the bytes on the page.
    ///
    /// Asserted in **both** modes since A3b (#439). It used to be inline-only,
    /// because inline was the one mode whose iframe carried the log's content
    /// — a `data:` URI — while linking mode's carried a file name and nothing
    /// in this synthetic pipeline ever wrote the file. Rendering the log in the
    /// page removes that asymmetry: the same text reaches the same element
    /// either way, and the mode now decides only whether a `.log` file is
    /// written beside the report.
    func testBothModesEmbedTheActualLogBytes() {
        let expected = String(data: StubPayloadProvider.logText, encoding: .utf8) ?? ""
        for mode in [Summary.RenderingMode.inline, .linking] {
            let html = summary(renderingMode: mode).generatedHtmlReport()
            XCTAssertTrue(
                html.contains("<pre class=\"log-body\" tabindex=\"0\">\(expected)</pre>"),
                "\(mode): the fixture's log bytes must be on the page verbatim, "
                    + "not merely referenced"
            )
        }
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

    /// `SyntheticResultTests.testCoversHostileAttachmentFilename` proves the
    /// *fixture* contains a filename with `"` `'` `<` `>` `&`. This proves
    /// the *render* escapes it.
    ///
    /// Until #463 it did not: `Attachment` handed the raw filename to the
    /// substitution seam, so the embedded `"` terminated the attribute it
    /// was written into and `<GreaterThan>` entered the DOM as an element.
    /// The assertion was carried as an `XCTExpectFailure` from #461 until
    /// the escaping landed.
    ///
    /// Asserted against the attribute the filename actually lands in rather
    /// than against a handler's text. It used to read
    /// `onclick="showText('FileName with DoubleQuote…` — but A3a (#439) gave
    /// every attachment one handler that takes the element, so no handler
    /// contains a filename at all any more and that literal would now be
    /// absent from a report that escaped nothing. `HTMLEscapingTests`
    /// still holds the "no filename in a script context" half; this holds the
    /// half it was written for, which is that the value cannot close the
    /// attribute quoting it.
    func testHostileAttachmentFilenameDoesNotBreakOutOfAttribute() throws {
        let html = summary().generatedHtmlReport()
        let raw = "FileName with DoubleQuote\"SingleQuote'LessThan<GreaterThan>Ampersand&"

        // The attribute the filename lands in, escaped.
        try XCTAssertContains(
            html,
            "data=\"FileName with DoubleQuote&quot;SingleQuote&apos;LessThan"
                + "&lt;GreaterThan&gt;Ampersand&amp;"
        )
        XCTAssertFalse(
            html.contains(raw),
            "no attribute may carry the filename unescaped: the embedded double "
                + "quote would terminate it early and the angle brackets would "
                + "enter the DOM as elements"
        )
    }
}
