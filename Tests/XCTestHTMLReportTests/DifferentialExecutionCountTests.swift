//
//  DifferentialExecutionCountTests.swift
//
//  The cross-backend assertion for A3b's executions count (#439), in an
//  extension for the reason `DifferentialSummaryHeaderTests` gives: that file
//  is at its length limit and this shares its cached summaries.
//
//  This is the gate the port change was made against. `ParsedTestCase`
//  gained `executionCount` because Xcode states two numbers — 21 tests and 23
//  runs — and neither `iterations` nor `arguments` could carry the second:
//  both readers deliberately collapse a parameterized case's argument
//  executions into one iteration, and only the modern format names the
//  argument values at all. The count itself *is* in both bundles — legacy has
//  one sibling metadata entry per execution, modern one `Arguments` child —
//  and one of them was throwing it away. So the readers converge here rather
//  than one of them reading something new, and this is what holds them
//  converged.
//
//  `testMaskedRendersAreIdenticalAcrossBackends` would also catch a divergence,
//  since `data-runs` and the toolbar's figure are both rendered text. It would
//  report it as one more differing line in a diff of two documents; this
//  reports it as the identifier whose two counts disagree.
//

import XCTest
@testable import XCTestHTMLReportCore

extension DifferentialTests {
    func testExecutionCountsAgreeAcrossBackends() throws {
        try requireBothBackends()

        // Non-vacuity, checked across all fixtures at the end: if every test in
        // every bundle ran exactly once, the equalities below hold on any two
        // readers — including one that dropped the field entirely — and this
        // test would pass while proving nothing.
        var fixturesWhereExecutionsExceedTests = 0

        for fixture in Self.fixtures {
            let legacy = try summary(fixture, .legacy)
            let modern = try summary(fixture, .modern)

            // Before zipping, which truncates to the shorter side.
            XCTAssertEqual(
                legacy.runs.count, modern.runs.count,
                "\(fixture): backends disagree on the number of runs"
            )

            for (index, pair) in zip(legacy.runs, modern.runs).enumerated() {
                let (legacyRun, modernRun) = pair

                /// Per test, not just per run: two backends can reach the same
                /// total from different rows, and a total-only assertion would
                /// report the disagreement without naming what disagrees.
                func counts(_ run: Run) -> [String: Int] {
                    Dictionary(
                        run.allTests.map { ($0.identifier, $0.executionCount) },
                        uniquingKeysWith: { first, _ in first }
                    )
                }
                XCTAssertEqual(
                    counts(legacyRun), counts(modernRun),
                    "\(fixture) run \(index): identifier→executions differs between backends"
                )
                XCTAssertEqual(
                    legacyRun.numberOfExecutions, modernRun.numberOfExecutions,
                    "\(fixture) run \(index): the toolbar's executions figure differs"
                )
                if legacyRun.numberOfExecutions > legacyRun.numberOfTests {
                    fixturesWhereExecutionsExceedTests += 1
                }
            }
        }

        XCTAssertGreaterThan(
            fixturesWhereExecutionsExceedTests, 0,
            "no fixture ran a test more than once, so nothing above "
                + "distinguishes a converged reader from one that returns 1 "
                + "for everything. TestResults holds a parameterized @Test and "
                + "RetryResults is generated with -test-iterations 2; if "
                + "neither still does, this suite has stopped covering the "
                + "field it exists for"
        )
    }
}
