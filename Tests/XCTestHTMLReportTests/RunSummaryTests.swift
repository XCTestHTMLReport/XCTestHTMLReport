//
//  RunSummaryTests.swift
//
//  The summary header (#439, A1). Driven by the synthetic fixture, which is
//  the only one whose numbers are constants — the generated .xcresult bundles
//  are regenerated on every run, so nothing there can be pinned exactly.
//

import SwiftSoup
import XCTest
@testable import XCTestHTMLReportCore

final class RunSummaryTests: XCTestCase {
    private func summary(_ run: ParsedRun = SyntheticResult.parsedRun) -> Summary {
        Summary(
            parsedRuns: [run],
            payloads: SyntheticResult.payloads,
            renderingMode: .linking,
            downsizeImagesEnabled: false,
            downsizeScaleFactor: 0.5,
            bundleNames: ["Synthetic"]
        )
    }

    private func document(_ run: ParsedRun = SyntheticResult.parsedRun) throws -> Document {
        try SwiftSoup.parse(summary(run).generatedHtmlReport())
    }

    /// The six statuses partition the tests, so the ring is a whole circle
    /// rather than a circle with a gap in it.
    ///
    /// The fixture puts a test in each of five buckets — two in `passed`
    /// since A3b added a parameterized case — which is also what makes the
    /// legend below assertable: any bucket that stopped being counted would
    /// drop a row rather than change a number.
    func testLegendCountsEveryStatusTheFixtureProduces() throws {
        let rows = try document().select("ul.summary-legend li").array()
        XCTAssertEqual(
            try rows.map { try $0.text() },
            [
                "Passed 2",
                "Failed 1",
                "Skipped 1",
                "Mixed 1",
                "Expected failures 1",
            ],
            "the legend must name every bucket the fixture fills, and only those"
        )

        let total = try document().select(".donut-center strong").text()
        XCTAssertEqual(total, "6", "the ring's centre states the run's test count")
    }

    /// The bucket `Status` folds nowhere else: before #439 an expected failure
    /// landed in no header count at all, so a run of nothing but expected
    /// failures reported zero tests in every bucket. It is surfaced from the
    /// model both readers already populate, so this holds on either backend.
    func testExpectedFailuresAreCountedRatherThanDropped() {
        let tally = RunSummary(runs: summary().runs).tally
        XCTAssertEqual(tally.expectedFailure, 1)
        XCTAssertEqual(
            tally.total,
            tally.passed + tally.failed + tally.skipped
                + tally.mixed + tally.expectedFailure + tally.unknown,
            "every test must land in exactly one bucket"
        )
        XCTAssertEqual(tally.total, summary().runs.flatMap(\.allTests).count)
    }

    /// The header's duration is the sum of the *leaf* tests, never of the
    /// groups. The fixture makes the two answers different on purpose: its
    /// group declares 6s while its six test cases add up to 10.5s (five at
    /// 1.5s plus a retried one with two 1.5s iterations).
    ///
    /// The parameterized case contributes 1.5s and not 4.5s, deliberately: it
    /// is one iteration however many argument sets produced it, and both
    /// readers collapse it that way. Its three executions are a count, not a
    /// duration.
    ///
    /// This is the assertion that keeps the cross-backend differential green
    /// without an allow-list entry. `durationInSeconds` is null on every suite
    /// node in the modern format — the standing `durations` known loss — so a
    /// total that reached for a group's duration would read 6s on one backend
    /// and 0s on the other.
    func testDurationSumsLeafTestsAndNotGroups() throws {
        let meta = try document().select("#run-summary-heading .summary-meta").text()
        XCTAssertEqual(meta, "Duration (10.50s) · 1 device")

        let group = SyntheticResult.parsedRun.testables[0].groups[0]
        XCTAssertEqual(group.duration, 6, "the fixture's group must disagree with its leaves")
    }

    /// The header's total inherits a declared divergence — a parameterized
    /// Swift Testing case reports a different duration on each backend (#477)
    /// — so it has to be written in a shape the differential's `durations`
    /// known-loss rule normalises, or the cross-backend comparison goes red on
    /// whichever runner is slow enough to cross a rounding boundary.
    ///
    /// Asserted against `KnownLossMasker` itself rather than by reading the
    /// regex and believing it. That distinction is the whole point: the shape
    /// is `(N.NNs)`, and a copy edit that dropped the parentheses — which look
    /// like styling — would silently uncover the divergence. This fails the
    /// moment that happens.
    func testTheHeadersDurationIsWrittenInAMaskedShape() throws {
        let rendered = summary().generatedHtmlReport()
        try XCTAssertContains(rendered, "<span class=\"summary-duration\">(10.50s)</span>")

        let masked = KnownLossMasker.mask(rendered, rules: ["durations"])
        XCTAssertFalse(
            masked.contains("(10.50s)"),
            "the durations rule must normalise the header's total, as it does "
                + "every duration in the tree"
        )
        try XCTAssertContains(masked, "(DURATION)")
    }

    /// The ring covers the full circle and each arc starts where the last one
    /// ended, which is what makes it readable as proportions at all.
    func testRingArcsTileTheWholeCircle() throws {
        let arcs = try document().select("circle.donut-seg").array()
        XCTAssertEqual(arcs.count, 5, "one arc per non-empty bucket")

        var expectedStart = 0.0
        var covered = 0.0
        for arc in arcs {
            let dash = try XCTUnwrap(
                Double(arc.attr("stroke-dasharray").split(separator: " ")[0])
            )
            // The offset is negative: it rotates the dash pattern forward by
            // everything already drawn.
            let offset = try XCTUnwrap(Double(arc.attr("stroke-dashoffset")))
            let arcName = try arc.className()
            XCTAssertEqual(
                -offset, expectedStart, accuracy: 0.001,
                "arc \(arcName) does not start where the previous one ended"
            )
            expectedStart += dash
            covered += dash
        }
        XCTAssertEqual(covered, 100, accuracy: 0.001, "the arcs must tile the circle")
    }

    /// The digest is the direction's strongest claim — failures readable
    /// without expanding anything — so it has to carry the message, not just
    /// the name.
    func testFailureDigestCarriesTheAssertionMessage() throws {
        let rows = try document().select("ul.failure-digest li").array()
        XCTAssertEqual(rows.count, 1, "the fixture has exactly one failed test")

        let row = try XCTUnwrap(rows.first)
        XCTAssertEqual(try row.select(".digest-jump").text(), "testFails()")
        XCTAssertEqual(
            try row.select(".digest-message").text(),
            "Synthetic.swift:42: assertion failed",
            "the message is the failing activity's title, which is what the "
                + "tree's red row shows"
        )
        XCTAssertEqual(
            try row.select(".digest-suite").text(), "Synthetic",
            "the suite comes from the test identifier, the one key the "
                + "differential pins as equal across backends"
        )
    }

    /// A jump button whose target is not in the document is a dead link, and
    /// nothing else in the suite would notice: the id it points at is built
    /// from a different path than the digest walks.
    func testEveryDigestJumpTargetsAnElementInTheDocument() throws {
        let page = try document()
        let buttons = try page.select("button.digest-jump").array()
        XCTAssertFalse(buttons.isEmpty, "the fixture must produce a digest to check")

        for button in buttons {
            let uuid = try button.attr("data-target")
            XCTAssertFalse(uuid.isEmpty, "a jump button with no target is inert")
            let disclosure = try page.getElementById("activities-\(uuid)")
                ?? page.getElementById("iterations-\(uuid)")
            XCTAssertNotNil(
                disclosure,
                "no element for \(uuid): the digest points at a row the page "
                    + "does not contain"
            )
            let owningRow = try disclosure?.parent()
            XCTAssertNotNil(
                owningRow,
                "the disclosure must sit inside the row the script scrolls to"
            )
            XCTAssertTrue(
                owningRow?.hasClass("test-summary") == true,
                "the script walks up to the nearest .test-summary; \(uuid)'s "
                    + "disclosure is not inside one"
            )
        }
    }

    /// No failures, no card. An empty digest answers nothing and costs a
    /// screenful of the space the header is already spending.
    func testDigestIsOmittedWhenNothingFailed() throws {
        let passing = ParsedRun(
            destination: SyntheticResult.parsedRun.destination,
            logReference: SyntheticResult.logReference,
            testables: [ParsedTestable(
                targetName: "SyntheticTests",
                groups: [ParsedGroup(
                    name: "SyntheticSuite",
                    identifier: "SyntheticSuite",
                    duration: 1,
                    children: [.testCase(SyntheticResult.testCase(
                        name: "testPasses()",
                        iterations: [SyntheticResult.iteration(
                            number: nil, status: .passed, activities: []
                        )]
                    ))]
                )]
            )]
        )
        let page = try document(passing)
        XCTAssertTrue(
            try page.select("ul.failure-digest").isEmpty(),
            "a clean run must not render an empty failure digest"
        )
        XCTAssertFalse(
            try page.select("ul.summary-legend li").isEmpty(),
            "the rest of the header still renders"
        )
    }

    /// One option per run, whatever the run count, because the ring only ever
    /// speaks for the whole report.
    ///
    /// A1 drew these as rows in the summary band's third column and A3a moves
    /// them into the header device picker (#439) — the "one control, not two"
    /// decision: the thing that states a destination's split and the thing
    /// that switches to it are the same element now. What the row *says* is
    /// unchanged, which is why the assertions below are, and the classes they
    /// name (`.device-row-name`, `.device-row-tally`) are still A1's.
    func testOneDeviceOptionPerRun() throws {
        let page = try document()
        let options = try page.select(".picker-panel .device-option").array()
        XCTAssertEqual(options.count, 1)
        XCTAssertEqual(
            try XCTUnwrap(options.first).select(".device-row-name").text(),
            "Synthetic Device 1.0"
        )
        XCTAssertEqual(
            try XCTUnwrap(options.first).select(".device-row-tally").text(),
            "2 passed, 1 failed, 1 skipped, 1 mixed, 1 expected failure",
            "the bar is aria-hidden, so this caption is the only accessible "
                + "reading of the proportions it draws"
        )
    }

    /// The picker is the sidebar's whole job, so every navigation the sidebar
    /// offered has to be reachable from it: which destinations exist, which
    /// one is showing, each one's outcome, and a way to switch.
    ///
    /// It lives in the title band rather than in the summary band, and that
    /// placement is load-bearing rather than aesthetic: the band stands down
    /// for the Logs view (A2), so a picker inside it would make choosing a
    /// destination impossible on exactly the view where a multi-run report
    /// most needs it — every run has its own log.
    func testThePickerCarriesEverythingTheDeviceSidebarDid() throws {
        let page = try document()

        let picker = try XCTUnwrap(
            page.select("#title .device-picker").first(),
            "the picker must sit in the title band, above the band that stands "
                + "down for the Logs view"
        )
        XCTAssertEqual(
            try picker.select("#device-picker-current").text(), "Synthetic Device 1.0",
            "the collapsed picker must name the destination on screen"
        )

        let option = try XCTUnwrap(picker.select("button.device-option").first())
        let handle = try option.attr("data-device")
        XCTAssertFalse(handle.isEmpty, "an option must carry the handle it switches to")
        // The attribute and the handler have to name the same run. The script
        // reaches for the attribute in two places the handler cannot serve —
        // the boot sequence, and a digest jump into another destination's tree
        // — so a drift between them would leave those two selecting a
        // different run from the one a click selects.
        XCTAssertEqual(
            try option.attr("onclick").groupMatch("selectDevice\\('([^']*)'"),
            handle,
            "the option's handler and its data-device must address one run"
        )
        XCTAssertFalse(
            try option.select(".icon.device-result").isEmpty(),
            "the sidebar card had a status cell; the picker states the outcome"
        )
        XCTAssertEqual(
            try option.select(".device-option-meta").text(), "Synthetic Model",
            "the sidebar named the model, so the picker does"
        )

        // Both per-view slices the option addresses must exist, or switching
        // destination would leave one view showing the previous one's content.
        for view in ["tests", "logs"] {
            XCTAssertNotNil(
                try page.getElementById("\(view)_\(handle)"),
                "the picker's handle must address the \(view) view"
            )
        }
    }
}
