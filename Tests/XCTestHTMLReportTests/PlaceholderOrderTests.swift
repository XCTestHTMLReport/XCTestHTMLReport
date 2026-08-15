//
//  PlaceholderOrderTests.swift
//
//  Order, not escaping (#439, A3a review).
//
//  A separate file from `HTMLEscapingTests` because it pins a different
//  failure: every value here is correctly escaped and still changes the markup
//  around it. A template filled by a chain of `replacingOccurrences` fills the
//  placeholders an earlier replacement *inserted* as readily as the ones the
//  template author wrote, and `[[` and `]]` are ordinary characters that
//  XML escaping has no reason to touch — so a destination named after a
//  placeholder is a second substitution surface.
//
//  Assertions run against the whole document rather than a extracted region:
//  the strings below are exact enough to be unique, and a document-wide count
//  is the stronger reading of "nothing else appeared".
//

import XCTest
@testable import XCTestHTMLReportCore

final class PlaceholderOrderTests: XCTestCase {
    /// The rule the picker's two chains follow: a value is protected by going
    /// in *after* every placeholder it could spell, never before.
    ///
    /// This is not reachable as XSS — every value in the chain is either an
    /// opaque digest or escaped leaf text. What it did before the A3a review
    /// was corrupt the reading: a destination called `[[DEVICE_IDENTIFIER]]`
    /// rendered a 32-character digest as its own name, and one called
    /// `[[DEVICE_OPTIONS]]` pulled the picker's whole panel of buttons into
    /// the collapsed summary's one-line span. Both orders are the other way
    /// round now; this is what holds them there.
    func testADestinationNamedAfterAPlaceholderIsNotFilledByIt() {
        let html = placeholderNamedRunHTML()
        let name = "Device [[DEVICE_IDENTIFIER]] and [[DEVICE_OPTIONS]]"
        let label = "\(name) <span class=\"device-row-os\">1.0</span>"

        XCTAssertTrue(
            html.contains(
                "<span class=\"picker-current\" id=\"device-picker-current\">\(label)</span>"
            ),
            "the collapsed summary must hold the destination's own name — not a "
                + "digest standing in for part of it, and not the panel of "
                + "options that name spells"
        )
        XCTAssertTrue(
            html.contains("<span class=\"device-row-name\">\(label)</span>"),
            "and the option must read the same way"
        )
        XCTAssertTrue(
            html.contains("Model [[DEVICE_TALLY]]"),
            "the model is the other test-plan string in the chain, and the bar's "
                + "own markup goes in before it"
        )
        XCTAssertEqual(
            occurrences(of: "class=\"device-option\"", in: html), 1,
            "one run is one option — a destination that names a placeholder "
                + "must not be able to put a second control in the picker"
        )
    }

    /// What ordering alone cannot fix, stated as a test rather than left in a
    /// comment.
    ///
    /// Two of the picker's placeholders carry test-plan text, and no order
    /// protects both: whichever goes in first is in the string when the second
    /// one runs. `[[CURRENT_DEVICE]]` is the one left reachable, deliberately
    /// — it expands to a destination *label*, so a model that names it gets a
    /// second name inside it, where the opposite order handed a destination
    /// the picker's entire panel of buttons. Text, where the alternative was
    /// controls.
    ///
    /// Closing the class outright means substituting in a single pass that
    /// never rescans what it inserted. That is a property of the whole `HTML`
    /// seam — every template in the report is filled the same way, and has
    /// been since long before A3a — so it is a change to the seam rather than
    /// to this renderer. Until then this is the boundary, and it is asserted:
    /// garbled text is inside it, a control is not.
    func testTheOneReachablePlaceholderCanStillOnlyInsertText() {
        let html = currentDeviceNamedRunHTML()

        // Scoped to the span the model lands in, not merely present somewhere in
        // the document: this is the precondition, and a precondition that a
        // stray copy elsewhere could satisfy is not one. It asserts the fixture
        // arrived, deliberately not what the placeholder after it became — that
        // is the behaviour under test, and pinning today's answer to it would
        // make this test fail the day the seam stops rescanning what it
        // inserted, which is the outcome it is arguing for.
        XCTAssertTrue(
            html.contains("<span class=\"device-option-meta\">Model Two"),
            "the fixture's model must reach the picker's option, or nothing here "
                + "is under test"
        )
        XCTAssertEqual(
            occurrences(of: "class=\"device-option\"", in: html), 1,
            "the one placeholder no ordering protects must not be able to put a "
                + "control anywhere in the picker"
        )
        XCTAssertEqual(
            occurrences(of: "id=\"device-picker-current\"", in: html), 1,
            "nor a second collapsed summary"
        )
    }

    /// The per-view templates are *closed*, not merely ordered (#439, A3b).
    ///
    /// `Run` fills two templates from two lists rather than one dictionary, and
    /// each list holds only what its own template needs — so the one value in
    /// each that a test author controls goes in last, with nothing after it to
    /// fill. That is stronger than ordering: a test named after the log's
    /// placeholder is not merely filled late, it is unfillable, because the
    /// Tests list has no such entry at all.
    ///
    /// Both directions, because the hazard is symmetric and a dictionary in
    /// hash order could have substituted either value into the other.
    func testATestNamedAfterTheLogsPlaceholderIsNotFilledByIt() {
        let html = report(
            testName: "test[[LOG_TEXT]]()",
            log: "a line belonging to the log alone"
        )

        try? XCTAssertContains(html, "test[[LOG_TEXT]]()")
        XCTAssertEqual(
            occurrences(of: "a line belonging to the log alone", in: html), 1,
            "the log belongs to the Logs view and nowhere else — a test that "
                + "spells its placeholder must not pull it into the tree"
        )
    }

    func testALogLineNamedAfterTheTreesPlaceholderIsNotFilledByIt() {
        let html = report(
            testName: "testOrdinary()",
            log: "a log line reading [[TEST_SUMMARIES]]"
        )

        try? XCTAssertContains(html, "a log line reading [[TEST_SUMMARIES]]")
        XCTAssertEqual(
            occurrences(of: "testOrdinary()", in: html), 1,
            "and the tree must not be pulled into the log by a line that "
                + "spells its placeholder"
        )
    }

    /// A run holding one named test and one crafted log.
    private func report(testName: String, log: String) -> String {
        let logReference = "crafted-log"
        let run = ParsedRun(
            destination: SyntheticResult.parsedRun.destination,
            logReference: logReference,
            testables: [ParsedTestable(
                targetName: "SyntheticTests",
                groups: [ParsedGroup(
                    name: "SyntheticSuite",
                    identifier: "SyntheticSuite",
                    duration: 1,
                    children: [.testCase(SyntheticResult.testCase(
                        name: testName,
                        iterations: [SyntheticResult.iteration(
                            number: nil, status: .passed, activities: []
                        )]
                    ))]
                )]
            )]
        )
        return Summary(
            parsedRuns: [run],
            payloads: StubPayloadProvider(exports: [logReference: Data(log.utf8)]),
            renderingMode: .linking,
            downsizeImagesEnabled: false,
            downsizeScaleFactor: 0.5,
            bundleNames: ["Synthetic"]
        ).generatedHtmlReport()
    }

    private func occurrences(of needle: String, in haystack: String) -> Int {
        haystack.components(separatedBy: needle).count - 1
    }

    /// A run whose destination fields are the literal text of the placeholders
    /// that render them.
    private func placeholderNamedRunHTML() -> String {
        report(
            displayName: "Device [[DEVICE_IDENTIFIER]] and [[DEVICE_OPTIONS]]",
            modelName: "Model [[DEVICE_TALLY]]"
        )
    }

    /// A run whose model names the one placeholder that is still reachable.
    private func currentDeviceNamedRunHTML() -> String {
        report(displayName: "Device Two", modelName: "Model Two [[CURRENT_DEVICE]]")
    }

    private func report(displayName: String, modelName: String) -> String {
        let run = ParsedRun(
            destination: ParsedDestination(
                displayName: displayName,
                deviceIdentifier: "00000000-0000-0000-0000-000000000000",
                modelName: modelName,
                operatingSystemVersion: "1.0"
            ),
            logReference: SyntheticResult.logReference,
            testables: SyntheticResult.parsedRun.testables
        )
        return Summary(
            parsedRuns: [run],
            payloads: SyntheticResult.payloads,
            renderingMode: .linking,
            downsizeImagesEnabled: false,
            downsizeScaleFactor: 0.5,
            bundleNames: ["Synthetic"]
        ).generatedHtmlReport()
    }
}
