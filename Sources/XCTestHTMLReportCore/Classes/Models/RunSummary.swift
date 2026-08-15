//
//  RunSummary.swift
//  XCTestHTMLReport
//
//  The Xcode-native summary header (#439, redesign step A1): the outcome
//  ring, the per-device bars and the failure digest that sit above the tree.
//
//  Everything here is *derived*. No reader was touched to build it, and the
//  differential allow-list is not grown. Two derivations, measured against
//  all three fixtures on both backends:
//
//  - **Counts.** `Status` partitions the leaf tests exactly (passed, failed,
//    skipped, mixed, expected failure, unknown sum to the total on every
//    fixture), and the differential already pins four of the six per run.
//    These are compared byte for byte across backends; nothing masks them.
//
//  - **Duration.** The sum of *leaf* test durations, never of groups:
//    `durationInSeconds` is null on every suite node in the modern format,
//    which is the standing `durations` allow-list entry, so a total that
//    reached for a group's duration would read a real value on one backend
//    and zero on the other.
//
//    Summing leaves does not make the total backend-identical, and this file
//    does not pretend otherwise. Two leaf-level divergences reach it, and they
//    are different in kind:
//
//    1. *Structural, and fixable.* A parameterized Swift Testing case, where
//       legacy sums the argument executions and modern reports the node's own
//       value (measured on CI's TestResults: `parameterizedAddition(value:)`
//       at 0.001268s legacy against 0.000423s modern, carrying a 0.85ms
//       difference into a 5.04s total). This one predates the header: answer 8
//       of the migration design already solved the identical problem for
//       *repetitions* by summing in the renderer, and nobody applied it to
//       *arguments* when answer 6 added them. The follow-up issue named in
//       `DifferentialTests.testSummaryHeaderNumbersAgreeAcrossBackends` closes
//       it, and takes that test's by-name exclusion out with it.
//
//    2. *Measurement, and permanent.* A leaf the run repeated can differ by
//       microseconds, because the two formats measure and report the same
//       repetition independently — 144µs on `RetryTests/testRetryOnFailure()`
//       in one fixture generation, 0 in another, all of it in a single
//       repetition. The summing is already common to both readers, so there is
//       nothing here to converge. The migration spec records it as a measured
//       format property under Verification.
//
//    Either one alone is why the total is rendered `Duration (5.04s)` —
//    parenthesised, in the shape the `durations` rule normalises — rather than
//    in a shape that would leave a declared loss unmasked and fail the
//    differential intermittently, on whichever runner happened to be slow
//    enough to cross a rounding boundary. Note it follows that closing the
//    issue in (1) does **not** free the total to be written in any shape: (2)
//    keeps the masked shape necessary for as long as a repeated test can land
//    in a report.
//
//  `ParsedRun` carries no run date, so the header states a duration and no
//  start time. Deriving one from the earliest activity timestamp — which the
//  design mockup did — would be a field the differential does not cover.
//

import Foundation

/// The header's whole view model: one ring, one row per device, one digest.
struct RunSummary {
    let tally: Tally
    let devices: [DeviceRow]
    let failures: [FailureRow]
    let duration: TimeInterval
    /// The one glyph that speaks for the whole report, by the same rule
    /// `Summary` already applies to the title bar's icon: a failure anywhere
    /// wins, then a pass, then skipped. Recomputed here rather than threaded
    /// through a placeholder so this template renders standalone.
    let overallStatus: Status

    init(runs: [Run]) {
        tally = runs.map(\.tally).reduce(.empty, +)
        devices = runs.enumerated().map { DeviceRow(run: $1, ordinal: $0 + 1) }
        failures = runs.flatMap(\.failureRows)
        duration = runs.reduce(0) { $0 + $1.duration }
        if runs.contains(where: { $0.status == .failure }) {
            overallStatus = .failure
        } else if runs.contains(where: { $0.status == .success }) {
            overallStatus = .success
        } else {
            overallStatus = .skipped
        }
    }
}

extension RunSummary {
    /// How many tests landed in each terminal status.
    ///
    /// One field per `Status` case rather than a dictionary keyed by it: the
    /// ring, the legend and every device bar have to walk the buckets in the
    /// same order or the three readings of one run disagree, and a dictionary
    /// has no order to walk.
    struct Tally {
        var passed = 0
        var failed = 0
        var skipped = 0
        var mixed = 0
        var expectedFailure = 0
        var unknown = 0

        static let empty = Tally()

        var total: Int {
            passed + failed + skipped + mixed + expectedFailure + unknown
        }

        /// The buckets, in the fixed order every rendering of them uses, with
        /// the empty ones dropped.
        ///
        /// Dropped, not rendered as zeroes: Xcode's own summary names the
        /// outcomes a run produced, and a permanent "Mixed 0" row in a report
        /// that has never retried a test is noise. The ring is unaffected —
        /// a zero-count bucket draws a zero-length arc either way.
        var buckets: [Bucket] {
            [
                Bucket(status: .success, label: "Passed", count: passed),
                Bucket(status: .failure, label: "Failed", count: failed),
                Bucket(status: .skipped, label: "Skipped", count: skipped),
                Bucket(status: .mixed, label: "Mixed", count: mixed),
                Bucket(
                    status: .expectedFailure,
                    label: "Expected failures",
                    count: expectedFailure
                ),
                Bucket(status: .unknown, label: "Unknown", count: unknown),
            ].filter { $0.count > 0 }
        }

        init() {}

        init(tests: [Test]) {
            for test in tests {
                switch test.status {
                case .success: passed += 1
                case .failure: failed += 1
                case .skipped: skipped += 1
                case .mixed: mixed += 1
                case .expectedFailure: expectedFailure += 1
                case .unknown: unknown += 1
                }
            }
        }

        static func + (lhs: Tally, rhs: Tally) -> Tally {
            var sum = Tally()
            sum.passed = lhs.passed + rhs.passed
            sum.failed = lhs.failed + rhs.failed
            sum.skipped = lhs.skipped + rhs.skipped
            sum.mixed = lhs.mixed + rhs.mixed
            sum.expectedFailure = lhs.expectedFailure + rhs.expectedFailure
            sum.unknown = lhs.unknown + rhs.unknown
            return sum
        }
    }

    struct Bucket {
        let status: Status
        let label: String
        let count: Int

        /// How this bucket reads inside a sentence ("1 skipped, 2 expected
        /// failures"). Five of the six labels are participles and are already
        /// count-neutral; only the expected-failure one is a noun phrase and
        /// needs the number agreed with.
        var spoken: String {
            guard status == .expectedFailure else {
                return "\(count) \(label.lowercased())"
            }
            return count == 1 ? "1 expected failure" : "\(count) expected failures"
        }
    }

    /// One destination, as the device picker renders it (#439, A3a).
    ///
    /// A1 built this to draw a row in the summary band's "Devices &
    /// Configurations" card. A3a makes the same row the picker's option, which
    /// is the whole of the "one control, not two" decision: the thing that
    /// states a destination's pass/fail split and the thing that switches to
    /// it are now the same element, so they cannot disagree and neither has to
    /// be found twice.
    ///
    /// That costs three fields the card did not need — the element handle to
    /// switch to, the model to identify the destination by, and the run's own
    /// outcome for the glyph. All three come from the same `Run`; nothing new
    /// is read out of a bundle, so the differential is untouched.
    struct DeviceRow {
        let name: String
        let osVersion: String
        let model: String
        /// This run's 1-based position in the report.
        ///
        /// Rendered only when there is more than one run, and then only
        /// because a report can hold two runs whose destination fields are
        /// byte-for-byte equal: merging a bundle with itself, or two bundles
        /// recorded on one simulator, which is what `ReproducibilityTests`'
        /// duplicate-bundle case is built out of. Without it the picker offers
        /// two options a reader cannot tell apart whenever the tallies also
        /// match. The sidebar's answer was its `Identifier:` line, a path
        /// digest that differed per run and meant nothing; a position is the
        /// same fact in a form someone can act on.
        ///
        /// Derived from the run's index, not read from a bundle, so it agrees
        /// across backends by construction — the runs are built in argument
        /// order on both.
        let ordinal: Int
        /// The `IdentifierPath` digest that addresses this run's two per-view
        /// slices, `tests_<id>` and `logs_<id>`. Opaque by construction, which
        /// is what makes it safe to interpolate into the option's handler.
        let identifier: String
        let status: Status
        let tally: Tally

        init(run: Run, ordinal: Int) {
            name = run.runDestination.name
            osVersion = run.runDestination.targetDevice.osVersion
            model = run.runDestination.targetDevice.model
            identifier = run.runDestination.targetDevice.uniqueIdentifier
            status = run.status
            tally = run.tally
            self.ordinal = ordinal
        }
    }

    /// One line of the failure digest.
    struct FailureRow {
        /// The failing test's element id, which is what the digest's jump
        /// button hands back to the page. Path-derived like every other id
        /// (#430), so it is stable across renders and normalised away in the
        /// cross-backend differential.
        let uuid: String
        let testName: String
        /// The owning suite, taken from the *identifier* rather than from the
        /// parent group's title. The identifier is the one key the
        /// differential already pins as equal across backends
        /// (`testStatusesAndCountsMatchAcrossBackends`), whereas the legacy
        /// tree wraps every suite in "Selected tests" and "<target>.xctest"
        /// levels the modern tree does not have.
        let suiteName: String
        /// The first failing activity's title, which is the assertion message
        /// the tree shows on the red row. Empty when a test is failed but
        /// recorded no failure activity.
        let message: String
    }
}

extension Run {
    var tally: RunSummary.Tally {
        RunSummary.Tally(tests: allTests)
    }

    /// Wall time this run's tests account for.
    ///
    /// Leaves only — see the note at the top of this file. `allTests` already
    /// flattens the tree to its leaves, so a group's own duration is never
    /// added on top of the cases it contains, and the modern format's null
    /// suite durations cannot reach the total.
    var duration: TimeInterval {
        allTests.reduce(0) { $0 + $1.duration }
    }

    var failureRows: [RunSummary.FailureRow] {
        allTests
            .filter { $0.status == .failure }
            .map { test in
                RunSummary.FailureRow(
                    uuid: test.uuid,
                    testName: test.title,
                    suiteName: Self.suiteName(of: test.identifier),
                    message: Self.firstFailureMessage(of: test) ?? ""
                )
            }
    }

    /// `FirstSuite/testTwo()` → `FirstSuite`; a bare identifier → nothing.
    private static func suiteName(of identifier: String) -> String {
        let components = identifier.split(separator: "/")
        guard components.count > 1 else {
            return ""
        }
        return String(components[components.count - 2])
    }

    /// The assertion message the tree's red row carries, for the digest.
    ///
    /// Only `TestCase` holds iterations, and only iterations hold activities;
    /// `allTests` yields leaves, so anything that is not a `TestCase` — an
    /// empty group counted as a leaf — simply has no message.
    private static func firstFailureMessage(of test: Test) -> String? {
        guard let testCase = test as? TestCase else {
            return nil
        }
        for iteration in testCase.iterations where iteration.status == .failure {
            if let failure = firstFailure(in: iteration.activities) {
                return failure.title
            }
        }
        return nil
    }

    /// Pre-order, so the message is the first failure the tree shows rather
    /// than whichever one a breadth-first walk happened to reach first.
    ///
    /// Not `Activity.failingActivityRecursive`: that returns the outermost
    /// activity *containing* a failure, whose title is the step's name
    /// ("Set Up"), not the assertion text.
    private static func firstFailure(in activities: [Activity]) -> Activity? {
        for activity in activities {
            if activity.isFailure {
                return activity
            }
            if let nested = firstFailure(in: activity.subActivities) {
                return nested
            }
        }
        return nil
    }
}
