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
    /// The fixture puts exactly one test in each of five buckets, which is
    /// also what makes the legend below assertable: any bucket that stopped
    /// being counted would drop a row rather than change a number.
    func testLegendCountsEveryStatusTheFixtureProduces() throws {
        let rows = try document().select("ul.summary-legend li").array()
        XCTAssertEqual(
            try rows.map { try $0.text() },
            [
                "Passed 1",
                "Failed 1",
                "Skipped 1",
                "Mixed 1",
                "Expected failures 1",
            ],
            "the legend must name every bucket the fixture fills, and only those"
        )

        let total = try document().select(".donut-center strong").text()
        XCTAssertEqual(total, "5", "the ring's centre states the run's test count")
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
    /// group declares 6s while its five test cases add up to 9s (four at 1.5s
    /// plus a retried one with two 1.5s iterations).
    ///
    /// This is the assertion that keeps the cross-backend differential green
    /// without an allow-list entry. `durationInSeconds` is null on every suite
    /// node in the modern format — the standing `durations` known loss — so a
    /// total that reached for a group's duration would read 6s on one backend
    /// and 0s on the other.
    func testDurationSumsLeafTestsAndNotGroups() throws {
        let meta = try document().select("#run-summary-heading .summary-meta").text()
        XCTAssertEqual(meta, "Ran for 9.00s · 1 device")

        let group = SyntheticResult.parsedRun.testables[0].groups[0]
        XCTAssertEqual(group.duration, 6, "the fixture's group must disagree with its leaves")
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

    /// One row per run, whatever the run count, because the ring only ever
    /// speaks for the whole report.
    func testOneDeviceRowPerRun() throws {
        let page = try document()
        let rows = try page.select(".device-row").array()
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(
            try XCTUnwrap(rows.first).select(".device-row-name").text(),
            "Synthetic Device 1.0"
        )
        XCTAssertEqual(
            try XCTUnwrap(rows.first).select(".device-row-tally").text(),
            "1 passed, 1 failed, 1 skipped, 1 mixed, 1 expected failure",
            "the bar is aria-hidden, so this caption is the only accessible "
                + "reading of the proportions it draws"
        )
    }
}
