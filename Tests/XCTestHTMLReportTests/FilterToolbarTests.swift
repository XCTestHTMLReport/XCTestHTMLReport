//
//  FilterToolbarTests.swift
//
//  The per-view toolbars A3b fills (#439, A3b; #460), asserted on the rendered
//  page over the synthetic fixture — whose inputs are constants, so the counts
//  below are determined by the fixture rather than by whatever the simulator
//  did this morning.
//
//  Three claims, one per feature:
//
//  - the status pills are the summary header's buckets made operable, which is
//    the whole of the #460 decision: expected failures already had a bucket in
//    A1's tally, and the filter row was the last reading of a run that still
//    had them in no bucket at all;
//  - the toolbar states executions as well as tests, from data both backends
//    carry;
//  - each view carries a real filter field where A3a reserved the slot — and
//    the Logs view carries its log, rather than an iframe pointed at another
//    origin that nothing in the page could filter.
//

import SwiftSoup
import XCTest
@testable import XCTestHTMLReportCore

final class FilterToolbarTests: XCTestCase {
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

    private func pills(_ page: Document) throws -> [Element] {
        try page.select("div.view-toolbar .filter-pills > button[role=radio]").array()
    }

    // MARK: - #460: the expected-failure bucket

    /// The pills and the legend are two readings of one `Tally`, so they name
    /// the same buckets in the same order and neither can grow a bucket the
    /// other lacks.
    ///
    /// This is the assertion #460 asked for. Before it, the row offered a
    /// fixed five — All, Passed, Skipped, Failed, Mixed — and an expected
    /// failure matched none of them: "Passed" left it on screen and "All"
    /// could not put it back, because "All" only ever set `display` on the
    /// four classes those five functions knew about.
    func testTheFilterRowOffersTheSameBucketsAsTheHeaderLegend() throws {
        let page = try document()
        let legend = try page.select("ul.summary-legend li").array()
            .map { try $0.select(".legend-count").text() }
        let legendLabels = try page.select("ul.summary-legend li").array()
            .map { try $0.ownText().trimmingCharacters(in: .whitespaces) }

        let rendered = try pills(page).map { try $0.text() }
        XCTAssertEqual(
            rendered.first, "All (6)",
            "the row leads with the whole run, which is the only pill the "
                + "legend has no counterpart for"
        )
        XCTAssertEqual(
            Array(rendered.dropFirst()),
            zip(legendLabels, legend).map { "\($0) (\($1))" },
            "every other pill is a legend bucket: same label, same count, same "
                + "order, because both are rendered from the run's Tally"
        )
        XCTAssertTrue(
            rendered.contains("Expected failures (1)"),
            "#460: the status the model has carried since #443 must have a "
                + "filter of its own"
        )
    }

    /// A pill selects rows by the class the renderer writes, so the mapping is
    /// `Status.cssClass` in both directions and there is no second list of
    /// class names in the page's JavaScript to fall out of step with it.
    func testEachPillNamesTheRowClassItSelects() throws {
        let page = try document()
        let filters = try pills(page).map { try $0.attr("data-filter") }
        XCTAssertEqual(
            filters,
            ["all", "succeeded", "failed", "skipped", "mixed", "expected-failure"],
            "the pills carry row classes, and `all` for the whole run"
        )

        for filter in filters.dropFirst() {
            XCTAssertFalse(
                try page.select("#view-tests .\(filter)").isEmpty(),
                "the pill for '\(filter)' selects nothing in this fixture, so "
                    + "it would filter the tree to an empty pane"
            )
        }
    }

    /// The counts must partition the run: the pills either add up to "All" or
    /// one of them is quietly counting a test twice, or not at all — which is
    /// exactly the state #460 describes, where the header counted six buckets
    /// and the toolbar filtered four.
    func testThePillCountsAddUpToTheWholeRun() throws {
        let counted = try pills(document()).dropFirst().reduce(0) { total, pill in
            try total + (Int(pill.text().groupMatch("\\((\\d+)\\)$") ?? "") ?? 0)
        }
        XCTAssertEqual(counted, 6, "every test lands in exactly one pill")
    }

    /// An empty bucket is dropped, by the rule the legend already follows: a
    /// permanent "Mixed (0)" in a report that never retried a test is noise,
    /// and — the part that matters for #460 — a status gets a pill *because*
    /// the run produced it, so a status nobody anticipated cannot end up
    /// unfilterable again.
    func testAnEmptyBucketGetsNoPill() throws {
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
        XCTAssertEqual(
            try pills(document(passing)).map { try $0.text() },
            ["All (1)", "Passed (1)"],
            "a run that only passed offers the two pills it can act on"
        )
    }

    // MARK: - Tests and runs

    /// Xcode's two numbers, on a fixture where they differ: six tests, nine
    /// executions — four cases ran once, the retried one twice and the
    /// parameterized one three times.
    func testTheToolbarStatesExecutionsAsWellAsTests() throws {
        let page = try document()
        XCTAssertEqual(
            try page.select("#view-tests .view-toolbar-count").text(),
            "9 executions",
            "one row is not one execution: repetitions and argument sets are "
                + "both executions the tree does not draw a row for"
        )
        XCTAssertEqual(
            summary().runs.first?.numberOfExecutions, 9,
            "the rendered figure and the model must be the same number"
        )
        XCTAssertEqual(
            summary().runs.first?.numberOfTests, 6,
            "and it must not have moved the test count with it"
        )
    }

    /// The executions a row accounts for, written onto the row so the page can
    /// re-derive the toolbar's figure from whichever rows a filter left
    /// showing. Absent when it is 1, which is most rows.
    func testOnlyRowsWithSeveralExecutionsCarryTheCount() throws {
        let page = try document()
        let carrying = try page.select("#view-tests .test-summary[data-runs]").array()
        XCTAssertEqual(
            try carrying.map { try (
                $0.select(".row-name").first()?.text() ?? "",
                $0.attr("data-runs")
            ) }
            .sorted { $0.0 < $1.0 }
            .map { "\($0.0)=\($0.1)" },
            ["testParameterized()=3", "testRetries()=2"],
            "the parameterized case ran three times and the retried one twice; "
                + "every other row ran once and carries no attribute"
        )
    }

    /// The mockup's own treatment of a parameterized row, and the thing that
    /// makes the toolbar's second number legible: without it a reader is told
    /// the run holds nine executions of six tests with no way to see which
    /// rows account for the difference.
    ///
    /// A retried test deliberately gets no tag — its iterations are rows
    /// already, and "2 arguments" beside two iteration rows would be a second,
    /// wrong reading of the same fact.
    func testAParameterizedRowSaysHowManyArgumentSetsItRan() throws {
        let page = try document()
        let notes = try page.select("#view-tests .row-arguments").array()
        XCTAssertEqual(
            try notes.map { try $0.text() },
            ["3 arguments"],
            "exactly the parameterized row carries the tag"
        )
        XCTAssertEqual(
            try page.select("#view-tests .row-note").array().map { try $0.text() },
            ["3 arguments", "1 failed, 1 succeeded"],
            "it wears the same chip as a retried row's outcome breakdown, and "
                + "a class of its own so the two are distinguishable"
        )
        let row = try XCTUnwrap(notes.first?.parent()?.select(".row-name").first())
        XCTAssertEqual(try row.text(), "testParameterized()")
    }

    // MARK: - The filter fields

    /// One control shape in both views, in the trailing slot A3a laid out for
    /// it, which is also where Xcode's test report puts its Filter field.
    func testBothViewsCarryANamedFilterField() throws {
        let page = try document()
        for (view, label) in [
            ("#view-tests", "Filter tests by name"),
            ("#view-logs", "Filter log lines"),
        ] {
            let field = try XCTUnwrap(
                page.select("\(view) .view-toolbar-trailing input.view-filter").first(),
                "\(view) must carry a filter field in the reserved slot"
            )
            XCTAssertEqual(try field.attr("type"), "search")
            XCTAssertEqual(
                try field.attr("aria-label"), label,
                "a placeholder is not an accessible name"
            )
        }
    }

    /// The log is in the document (#439, A3b).
    ///
    /// Behind the `<iframe src>` this replaces, the log was a `file://`
    /// sibling or a `data:` URI — a foreign origin either way — so nothing in
    /// the page could filter it, and it could not see the token layer, which
    /// is why the Logs view rendered as a white slab in dark mode. The inert
    /// "All Messages" label A3a left in this slot was the symptom.
    func testTheLogIsRenderedInThePageRatherThanBehindAnIframe() throws {
        let page = try document()
        XCTAssertTrue(
            try page.select("#view-logs iframe").isEmpty(),
            "a log on another origin cannot be filtered, scrolled or themed by "
                + "anything in this page"
        )
        XCTAssertTrue(
            try page.select(".view-toolbar-label").isEmpty(),
            "the inert 'All Messages' label is gone, not restyled"
        )

        let body = try XCTUnwrap(page.select("#view-logs pre.log-body").first())
        XCTAssertEqual(
            try body.text(trimAndNormaliseWhitespace: false),
            "Synthetic run log line one\nSynthetic run log line two\n",
            "the log's own text, from the same bytes the .log export carries, "
                + "with its line breaks intact"
        )
        XCTAssertEqual(
            try body.attr("tabindex"), "0",
            "a region a mouse can scroll must be reachable by a keyboard "
                + "(axe: scrollable-region-focusable)"
        )
        XCTAssertEqual(
            try page.select("#view-logs .view-toolbar-count").text(), "2 lines",
            "the toolbar states what the field acts on"
        )
    }

    /// The exported `.log` file is unchanged, which is what keeps #480's fix
    /// and `DifferentialLogTests` meaning what they meant: A3b changes where
    /// the log is *rendered*, not what is written.
    func testTheLogExportIsUnchanged() throws {
        let run = try XCTUnwrap(summary().runs.first)
        guard case let .url(url) = run.logContent else {
            return XCTFail("linking mode must still export the log to a file")
        }
        XCTAssertTrue(url.lastPathComponent.hasSuffix(".log"))
        XCTAssertEqual(
            run.logText,
            String(data: StubPayloadProvider.logText, encoding: .utf8),
            "and the text the page renders is those same bytes"
        )
    }

    /// A log with no trailing newline and one with a trailing newline hold the
    /// same number of lines, because the trailing one *ends* the last line.
    /// The script re-derives this count when the field is used, so a
    /// disagreement here would make the toolbar state a number the reader
    /// cannot find.
    func testTheLineCountAgreesWithWhatThePreShows() {
        func run(log: String) -> Run? {
            let parsed = ParsedRun(
                destination: SyntheticResult.parsedRun.destination,
                logReference: "log",
                testables: SyntheticResult.parsedRun.testables
            )
            return Summary(
                parsedRuns: [parsed],
                payloads: StubPayloadProvider(exports: ["log": Data(log.utf8)]),
                renderingMode: .inline,
                downsizeImagesEnabled: false,
                downsizeScaleFactor: 0.5,
                bundleNames: ["Synthetic"]
            ).runs.first
        }
        XCTAssertEqual(run(log: "")?.logLineCount, 0)
        XCTAssertEqual(run(log: "one")?.logLineCount, 1)
        XCTAssertEqual(run(log: "one\n")?.logLineCount, 1)
        XCTAssertEqual(run(log: "one\ntwo")?.logLineCount, 2)
        XCTAssertEqual(run(log: "one\ntwo\n")?.logLineCount, 2)
        XCTAssertEqual(run(log: "one\n\nthree\n")?.logLineCount, 3)
    }
}
