//
//  DifferentialSummaryHeaderTests.swift
//
//  The cross-backend assertions for #439's summary header, in an extension
//  rather than in `DifferentialTests` itself: that file was already at its
//  length limit, and these share its cached summaries, which is what keeps a
//  suite dominated by `xcresulttool` subprocess time from doubling.
//

import XCTest
@testable import XCTestHTMLReportCore

extension DifferentialTests {
    /// The one leaf duration the summary header's total is allowed to inherit
    /// a divergence from (#477).
    ///
    /// Legacy merges a parameterized Swift Testing case's argument executions
    /// into iterations and so sums their durations; the modern reader reports
    /// the node's own value. Measured on CI's `TestResults`: 0.001268s against
    /// 0.000423s, three argument sets. Every other leaf agrees exactly.
    ///
    /// Narrower than `testXCTestCaseDurationsAgreeAcrossBackends`'s blanket
    /// `SwiftTestingSuite/` filter on purpose — the non-parameterized Swift
    /// Testing cases do agree, and this pins them. Delete this constant, and
    /// the `filter` that reads it, when #477 lands.
    private static let divergentDurationIdentifier =
        "SwiftTestingSuite/parameterizedAddition"

    /// What the summary header derives, asserted on the model rather than
    /// through the render — the same reason
    /// `testXCTestCaseDurationsAgreeAcrossBackends` exists.
    ///
    /// The header's *total* is deliberately not compared here: it sums leaves,
    /// and one leaf diverges (#477), so the total inherits that divergence.
    /// The header therefore writes its total in the parenthesised `(N.NNs)`
    /// shape the `durations` known-loss rule already normalises, and
    /// `RunSummaryTests.testTheHeadersDurationIsWrittenInAMaskedShape` proves
    /// that against the masker.
    ///
    /// What is asserted instead is stronger and does not rot: every leaf
    /// duration except that one identifier must agree *exactly*, and every
    /// status bucket must match. When #477 converges the two backends the
    /// exclusion becomes unnecessary, and the constant above says so.
    func testSummaryHeaderNumbersAgreeAcrossBackends() throws {
        try requireBothBackends()
        for fixture in Self.fixtures {
            let legacy = try summary(fixture, .legacy)
            let modern = try summary(fixture, .modern)

            func leafDurations(_ summary: Summary) -> [String: TimeInterval] {
                Dictionary(
                    summary.runs.flatMap(\.allTests)
                        .filter { !$0.identifier.hasPrefix(Self.divergentDurationIdentifier) }
                        .map { ($0.identifier, $0.duration) },
                    uniquingKeysWith: { first, _ in first }
                )
            }
            let legacyLeaves = leafDurations(legacy)
            XCTAssertFalse(
                legacyLeaves.isEmpty,
                "\(fixture): no leaves left to compare — the exclusion is too broad"
            )
            // Exact, not within a tolerance. A tolerance here is what let the
            // #477 divergence through in the first place: it was 0.85ms, well
            // inside any accuracy anyone would have picked.
            XCTAssertEqual(
                legacyLeaves, leafDurations(modern),
                "\(fixture): a leaf duration outside the one declared divergence "
                    + "differs between backends"
            )

            let legacyHeader = RunSummary(runs: legacy.runs)
            let modernHeader = RunSummary(runs: modern.runs)
            XCTAssertGreaterThan(
                legacyHeader.duration, 0,
                "\(fixture): a zero total would make the header vacuous"
            )
            XCTAssertEqual(
                legacyHeader.tally.buckets.map { "\($0.label) \($0.count)" },
                modernHeader.tally.buckets.map { "\($0.label) \($0.count)" },
                "\(fixture): the header's status buckets differ between backends"
            )
            XCTAssertEqual(
                legacyHeader.tally.total, legacy.runs.flatMap(\.allTests).count,
                "\(fixture): the buckets must account for every test"
            )
        }
    }
}
