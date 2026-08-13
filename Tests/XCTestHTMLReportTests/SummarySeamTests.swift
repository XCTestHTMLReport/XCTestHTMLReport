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

    /// `SyntheticResultTests.testCoversHostileAttachmentFilename` proves the
    /// *fixture* contains a filename with `"` `'` `<` `>` `&`. This proves
    /// the *render* escapes it — and it does not: `HTMLTemplates.swift`
    /// interpolates the raw filename into `onclick="showText('[[SOURCE]]')"`
    /// with no attribute escaping, so the embedded `"` breaks out of the
    /// `onclick` attribute early. The committed goldens already contain the
    /// broken markup this produces.
    ///
    /// This is a known, pre-existing HTML-injection defect in
    /// `HTMLTemplates.swift` / `Attachment.swift`, out of scope to fix here.
    /// `XCTExpectFailure` records it without turning the suite red: today it
    /// passes-as-expected-failure, and the moment someone fixes the
    /// escaping, this assertion starts succeeding, `XCTExpectFailure` turns
    /// that into a *failure* (an unexpectedly-passing expected failure), and
    /// the fix has to update this test — which is the signal that the
    /// defect is gone.
    func testHostileAttachmentFilenameDoesNotBreakOutOfAttribute() {
        XCTExpectFailure("""
        Known defect: HTMLTemplates.swift does not attribute-escape \
        attachment filenames, so a filename containing a double quote \
        breaks out of the onclick="showText('...')" attribute. Fixing the \
        escaping in HTMLTemplates.swift / Attachment.swift is out of scope \
        here; when it is fixed, this test will start passing and should be \
        promoted out of XCTExpectFailure.
        """)

        let html = summary().generatedHtmlReport()
        XCTAssertFalse(
            html.contains("onclick=\"showText('FileName with DoubleQuote\""),
            "the rendered attribute must not let the filename's embedded "
                + "double quote terminate the onclick attribute early"
        )
    }
}
