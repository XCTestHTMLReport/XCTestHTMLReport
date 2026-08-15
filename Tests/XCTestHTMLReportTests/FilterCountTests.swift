//
//  FilterCountTests.swift
//
//  The toolbar's two numbers on the *generated* fixtures (#439, A3b; #460).
//
//  `FilterToolbarTests` pins the same claims against the synthetic tree, whose
//  inputs are constants; these pin them against bundles a simulator produced,
//  where the counts come from the sample sources and — for `RetryResults` — from
//  how many repetitions the run happened to need.
//
//  An extension on `CoreTests` rather than a suite of its own, in the shape
//  `DifferentialSummaryHeaderTests` already uses: `testResultStatusCount` moved
//  here whole because A3b's additions put `CoreTests.swift` over its length
//  limit, and it shares that file's fixture accessors.
//

import SwiftSoup
import XCTest
@testable import XCTestHTMLReportCore

extension CoreTests {
    /// Every pill's count, keyed by its label.
    ///
    /// Read by label rather than by position: A3b renders the row from the
    /// run's tally, so it holds one pill per outcome the run produced — no
    /// "Mixed (0)" on a bundle that excludes the retry suite, and an "Expected
    /// failures" pill that exists only because this fixture has two (#460). A
    /// bucket with no pill reads as 0, which is what it means.
    private func pillCounts(in document: Document) throws -> [String: Int] {
        let pills = try document
            .select("div.view-toolbar .filter-pills > button[role=radio]")
            .eachText()
        return pills.reduce(into: [:]) { counts, text in
            guard let label = text.groupMatch("^(.+) \\(\\d+\\)$"),
                  let value = text.intGroupMatch("\\((\\d+)\\)$")
            else {
                return
            }
            counts[label] = value
        }
    }

    func testResultStatusCount() throws {
        let testResultsUrl = try XCTUnwrap(testResultsUrl)
        let summary = Summary(
            resultPaths: [testResultsUrl.path],
            renderingMode: .linking,
            downsizeImagesEnabled: false,
            downsizeScaleFactor: 0.5
        )

        let document = try SwiftSoup.parse(summary.html)

        try XCTContext.runActivity(named: "Test header contain the right number of results") { _ in
            let counts = try pillCounts(in: document)
            let (all, passed) = (counts["All"] ?? 0, counts["Passed"] ?? 0)
            let (skipped, failed) = (counts["Skipped"] ?? 0, counts["Failed"] ?? 0)
            let (mixed, expected) = (counts["Mixed"] ?? 0, counts["Expected failures"] ?? 0)

            // Fixtures are regenerated on every run, so assert only what the
            // sample sources actually determine, not the pass/fail split.
            //
            // The original reason for that caution -- the suites launched the
            // app in setUp with continueAfterFailure = false, so a slow
            // simulator turned a would-be pass into a failure -- no longer
            // applies: #423 removed those launches. The caution stands anyway,
            // because a run still depends on the simulator behaving, and an
            // exact split would measure that rather than this project.
            //
            // 21 = 16 XCTest methods + 5 Swift Testing `@Test` functions in
            // SwiftTestingSuite (SampleAppUnitTests target). Beyond the
            // original 13 XCTest methods: FirstSuite.testAttachScreenshot was
            // added by #393 to give the image rendering path a fixture, and
            // testExpectedFailure + testWithPngAttachment by #439 for the
            // redesign's status-icon and attachment-type work. The 4th `@Test`
            // is parameterizedAddition, added by the xcresulttool migration
            // (Task 8) to exercise `Arguments` nodes — its three argument sets
            // merge into one row, exactly like repetitions — and the 5th is
            // knownIssue (#439), Swift Testing's expected-failure counterpart.
            XCTAssertEqual(all, 21, "One row per test method; fixed by the sample sources")
            XCTAssertEqual(
                skipped,
                1,
                "SampleAppUnitTests.testSkipped is an unconditional XCTSkipIf"
            )
            XCTAssertEqual(mixed, 0, "TestResults excludes RetryTests, so nothing can be mixed")
            XCTAssertEqual(
                expected, 2,
                "testExpectedFailure and knownIssue, the sample sources' two " +
                    "deliberate expected failures — one from each test " +
                    "framework. #460: before A3b they were in no pill at all, " +
                    "neither shown by \"All\" nor hidden by \"Passed\""
            )
            XCTAssertEqual(
                passed + failed + skipped + mixed + expected,
                all,
                "Every test lands in exactly one bucket. The pills and the " +
                    "summary header's legend are now two readings of one " +
                    "tally — see `testSummaryHeaderAccountsForExpectedFailures` " +
                    "below, which asserts the same partition on the legend. " +
                    "Until A3b they disagreed: the header counted six buckets " +
                    "and the toolbar offered five, none of which an expected " +
                    "failure matched"
            )
            XCTAssertGreaterThanOrEqual(
                failed, 6,
                "Six sample tests fail deliberately (including SwiftTestingSuite.intentionalFailure); " +
                    "a lower count means failures are being lost"
            )
        }
    }

    /// Xcode's second number, on the fixture Xcode itself was measured on:
    /// `TestResults.xcresult` reads "All Tests (21)" and "All Runs (23)" in
    /// Xcode 26's viewer, and the two differ for exactly one reason —
    /// `parameterizedAddition(value:)` ran once per argument set.
    ///
    /// Pinned exactly rather than as an inequality, because both halves are
    /// fixed by the sample sources: 21 test methods, one of them parameterized
    /// over three values. It is also the assertion that would catch the legacy
    /// backend quietly losing the count again — it is the reader that has to
    /// recover it from sibling metadata entries, and `DifferentialTests`
    /// proves the two agree but not what they agree *on*.
    func testTheToolbarStatesXcodesRunCount() throws {
        let testResultsUrl = try XCTUnwrap(testResultsUrl)
        let summary = Summary(
            resultPaths: [testResultsUrl.path],
            renderingMode: .linking,
            downsizeImagesEnabled: false,
            downsizeScaleFactor: 0.5
        )
        let document = try SwiftSoup.parse(summary.html)

        XCTAssertEqual(
            try document.select("#view-tests .view-toolbar-count").text(),
            "23 executions",
            "21 tests, 23 executions — the three argument sets of "
                + "parameterizedAddition are two executions the tree draws no row for"
        )
        XCTAssertEqual(
            try document.select("#view-tests .test-summary[data-runs]").attr("data-runs"),
            "3",
            "and the row that accounts for them says so"
        )
        XCTAssertEqual(
            try document.select("#view-tests .row-arguments").text(),
            "3 arguments"
        )
    }

    /// The other half of the distinction, from the other direction: a run that
    /// repeated its tests holds more executions than rows.
    ///
    /// An inequality rather than an exact figure, because
    /// `-retry-tests-on-failure` stops repeating once a test passes — how many
    /// iterations a generation records depends on the simulator.
    func testARepeatedRunHoldsMoreExecutionsThanTests() throws {
        // Looked up here rather than through `CoreTests.getRetryResultsUrl`,
        // which lives in that file's `private extension`.
        guard let retryResultsUrl = Bundle.testBundle.url(
            forResource: "RetryResults", withExtension: "xcresult"
        ) else {
            throw XCTSkip("RetryResults.xcresult not found; Xcode < 13.0")
        }
        let summary = Summary(
            resultPaths: [retryResultsUrl.path],
            renderingMode: .linking,
            downsizeImagesEnabled: false,
            downsizeScaleFactor: 0.5
        )
        let document = try SwiftSoup.parse(summary.html)
        let run = try XCTUnwrap(summary.runs.first)

        XCTAssertGreaterThan(
            run.numberOfExecutions, run.numberOfTests,
            "RetryResults is generated with -test-iterations 2, so it must "
                + "hold more executions than rows"
        )
        XCTAssertEqual(
            try document.select("#view-tests .view-toolbar-count").text(),
            Run.executionsLabel(run.numberOfExecutions),
            "the rendered figure and the model must be the same number"
        )
    }
}
