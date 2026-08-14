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
    /// 0.000423s, three argument sets. This one is *structural* — the two
    /// readers assemble the number differently, so one of them can be changed
    /// to match, which is what #477 is for. Contrast the repetition case
    /// below, which is not structural and has no fix.
    ///
    /// Narrower than `testXCTestCaseDurationsAgreeAcrossBackends`'s blanket
    /// `SwiftTestingSuite/` filter on purpose — the non-parameterized Swift
    /// Testing cases do agree, and this pins them. Delete this constant, and
    /// the `filter` that reads it, when #477 lands.
    private static let divergentDurationIdentifier =
        "SwiftTestingSuite/parameterizedAddition"

    /// How far apart a *repeated* leaf's two durations may sit, per repetition.
    ///
    /// This is not the same phenomenon as #477 and is not a bug to be fixed.
    /// Both backends already sum repetitions by construction (design answer 8),
    /// so there is no structural divergence left to close: what remains is that
    /// the two formats *measure and report the same repetition independently*,
    /// each rounding to its own microsecond-scale value. Exact equality is not
    /// something either format promises for a repetition duration, and no
    /// renderer-side change can make it true.
    ///
    /// Measured on `RetryTests/testRetryOnFailure()`, two repetitions, across
    /// three `prepareTestResults.sh` generations of `RetryResults`:
    ///
    /// | generation | legacy | modern | Δ |
    /// | --- | --- | --- | --- |
    /// | review's | 0.14027798s | 0.14065396s | 376µs |
    /// | 2026-08-14 01:21 | 0.60440397s | 0.60440397s | 0 |
    /// | 2026-08-14 11:43 | 0.18024814s | 0.18039226s | 144µs |
    ///
    /// So it is generation-dependent, not constant — which is why an exact
    /// assertion here passed on CI and in development until a reviewer
    /// regenerated the bundle. The 11:43 generation also localises it: the
    /// gap is entirely in repetition 0 (0.12885606s against 0.12900018s) while
    /// repetition 1 is bit-identical. That is a per-repetition reporting
    /// difference, not an error in summing them — the sum is already common to
    /// both backends.
    ///
    /// The bound is set roughly five times the largest divergence anyone has
    /// measured (188µs per repetition) rather than snugly above it, because a
    /// bound has to survive that generation-to-generation variance to be worth
    /// asserting at all. Scaled per repetition because the leaf's duration is
    /// a sum: an N-times repeated case accumulates N independent
    /// measurements, so its worst case grows with N. Deliberately *not* a
    /// blanket tolerance — every leaf the run did not repeat is still compared
    /// exactly, below.
    ///
    /// Note the pre-existing `testXCTestCaseDurationsAgreeAcrossBackends`
    /// holds the same leaves to a flat `accuracy: 0.0005`, which is tighter
    /// than this for anything repeated twice. That is left alone deliberately:
    /// it is the older, blanket gate, and if a generation ever exceeds it, the
    /// right response is to give *that* assertion the same per-repetition
    /// treatment, not to loosen either one further.
    private static let repetitionDurationTolerancePerIteration: TimeInterval = 0.001

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
    /// duration except that one identifier must agree *exactly* — unless the
    /// run repeated the leaf, in which case it must agree within the bound
    /// above, for the reason stated there — and every status bucket must
    /// match. When #477 converges the two backends the exclusion becomes
    /// unnecessary, and the constant above says so.
    func testSummaryHeaderNumbersAgreeAcrossBackends() throws {
        try requireBothBackends()
        var repeatedLeavesCompared = 0
        for fixture in Self.fixtures {
            let legacy = try summary(fixture, .legacy)
            let modern = try summary(fixture, .modern)

            repeatedLeavesCompared += assertLeafDurationsAgree(
                fixture: fixture, legacy: legacy, modern: modern
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
        // `RetryResults` is generated with `-test-iterations 2
        // -retry-tests-on-failure`, so the tolerance branch above must have
        // run. If it did not, either that fixture stopped repeating anything
        // or both readers stopped reporting repetitions — and the weaker of
        // the two comparisons would have quietly become dead code.
        XCTAssertGreaterThan(
            repeatedLeavesCompared, 0,
            "no repeated leaf was compared — the fixtures no longer exercise "
                + "repetitions, so the per-repetition tolerance is unproven"
        )
    }

    /// Compares one fixture's leaf durations across the two backends and
    /// answers how many of them the run had repeated.
    ///
    /// Split out of the test above only to keep that method inside the length
    /// the linter enforces; it carries no assertions of its own beyond the
    /// duration comparison.
    private func assertLeafDurationsAgree(
        fixture: String, legacy: Summary, modern: Summary
    ) -> Int {
        let legacyLeaves = keyedByIdentifier(comparableLeaves(of: legacy), fixture)
        let modernLeaves = keyedByIdentifier(comparableLeaves(of: modern), fixture)
        XCTAssertFalse(
            legacyLeaves.isEmpty,
            "\(fixture): no leaves left to compare — the exclusion is too broad"
        )
        XCTAssertEqual(
            Set(legacyLeaves.keys), Set(modernLeaves.keys),
            "\(fixture): the backends disagree on which leaves exist, so "
                + "comparing their durations would compare different sets"
        )

        var repeatedLeaves = 0
        var exactLegacy: [String: TimeInterval] = [:]
        var exactModern: [String: TimeInterval] = [:]
        for (identifier, legacyLeaf) in legacyLeaves {
            guard let modernLeaf = modernLeaves[identifier] else {
                continue // Already failed on the key sets above.
            }
            // The repetition *count* is structural and must match exactly: it
            // is what makes the duration a sum of N measurements, and a backend
            // that dropped a repetition would otherwise hide inside the
            // tolerance that same count is used to size.
            let count = repetitions(of: legacyLeaf)
            XCTAssertEqual(
                count, repetitions(of: modernLeaf),
                "\(fixture): \(identifier) has a different number of "
                    + "repetitions on each backend"
            )
            guard count > 1 else {
                exactLegacy[identifier] = legacyLeaf.duration
                exactModern[identifier] = modernLeaf.duration
                continue
            }
            repeatedLeaves += 1
            XCTAssertEqual(
                legacyLeaf.duration, modernLeaf.duration,
                accuracy: Self.repetitionDurationTolerancePerIteration * Double(count),
                "\(fixture): \(identifier) repeated \(count) times and its two "
                    + "durations are further apart than independent measurement "
                    + "of the same repetitions explains"
            )
        }
        // Exact, not within a tolerance, for everything the run ran once. A
        // tolerance here is what let the #477 divergence through in the first
        // place: it was 0.85ms, well inside any accuracy anyone would have
        // picked.
        XCTAssertEqual(
            exactLegacy, exactModern,
            "\(fixture): a single-run leaf duration outside the one declared "
                + "divergence differs between backends"
        )
        return repeatedLeaves
    }

    /// Every leaf whose duration the two backends are expected to agree on —
    /// so, all of them but #477's.
    private func comparableLeaves(of summary: Summary) -> [Test] {
        summary.runs.flatMap(\.allTests)
            .filter { !$0.identifier.hasPrefix(Self.divergentDurationIdentifier) }
    }

    /// The same leaves keyed for comparison, failing rather than dropping if
    /// two of them share an identifier.
    ///
    /// They cannot today: every fixture is one test plan on one destination,
    /// so `runs` has one element. The moment that stops being true — the same
    /// plan run on two devices — the identifier alone stops being unique, and
    /// a `uniquingKeysWith` that keeps the first would quietly compare one of
    /// the two and report parity for both. That is the class of vacuous
    /// assertion this whole test exists to avoid, so it is asserted rather
    /// than assumed: a multi-run fixture will fail here and whoever adds it
    /// puts the run into the key.
    private func keyedByIdentifier(_ leaves: [Test], _ fixture: String) -> [String: Test] {
        let keyed = Dictionary(
            leaves.map { ($0.identifier, $0) }, uniquingKeysWith: { first, _ in first }
        )
        XCTAssertEqual(
            keyed.count, leaves.count,
            "\(fixture): two leaves share an identifier, so keying on it "
                + "compares only one of them — put the run in the key"
        )
        return keyed
    }

    /// Only `TestCase` carries repetitions; a leaf that is not one — an empty
    /// group — is a single measurement by definition.
    private func repetitions(of leaf: Test) -> Int {
        (leaf as? TestCase)?.iterations.count ?? 1
    }
}
