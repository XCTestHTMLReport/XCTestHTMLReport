//
//  TruncationFaultTests.swift
//
//  The fault that catches a run which stopped early (#478).
//
//  On the Xcode 27 beta the sample app trapped at launch, `SampleAppUnitTests`
//  never ran, and `xchtmlreport` rendered 10 of 21 tests, printed "Report
//  successfully created", and exited 0. A report that claims completeness while
//  silently dropping 57% of the suite is precisely what the fault machinery
//  exists to prevent.
//
//  The signal is read off `ParsedResult`, the model *both* readers produce, so
//  there is one implementation — the same seam `unresolvedLog` uses. One
//  implementation is not the same as one behaviour, which is why the second
//  half of this file exists: `testSelectedTargetWithNoTestRowsIsNotAFault`
//  guards the shape a withdrawn second fault kind got wrong. The name this rule
//  keys on is re-measured against the live toolchain by
//  `SystemFailureCanaryTests`; these tests pin the logic over synthetic input.
//
//  The crash shapes below were not guessed. `prepareTestResults.sh` reproduces
//  the crash by trapping in the host app's `didFinishLaunchingWithOptions`, and
//  both backends read the resulting bundle as:
//
//    legacy  ActionTestSummaryGroup name='System Failures'
//              └ (empty — the crash row is an ActionTestSummary, not decoded)
//    modern  Test Suite            name='System Failures'
//              └ Test Case         name='SampleApp (1669) encountered an error'
//

import XCTest
@testable import XCTestHTMLReportCore

final class TruncationFaultTests: XCTestCase {
    // MARK: Synthetic model builders

    private func run(testables: [ParsedTestable]) -> ParsedRun {
        ParsedRun(
            destination: ParsedDestination(
                displayName: "Synthetic Device",
                deviceIdentifier: "00000000-0000-0000-0000-000000000000",
                modelName: "Synthetic Model",
                operatingSystemVersion: "1.0"
            ),
            // No log reference: a run that never had one resolves to `.none`
            // by construction and records no `unresolvedLog`, so the fault sets
            // below hold only what these tests are about.
            logReference: nil,
            testables: testables
        )
    }

    private func testCase(_ name: String) -> ParsedNode {
        .testCase(ParsedTestCase(
            name: name,
            identifier: "Synthetic/\(name)",
            arguments: [],
            iterations: [ParsedIteration(
                iterationNumber: nil, status: .passed, duration: 1, activities: []
            )]
        ))
    }

    private func group(_ name: String, _ children: [ParsedNode]) -> ParsedGroup {
        ParsedGroup(name: name, identifier: name, duration: 1, children: children)
    }

    /// A `Summary` over synthetic runs, already validated.
    private func validatedSummary(_ runs: [ParsedRun]) -> Summary {
        let summary = Summary(
            parsedRuns: runs,
            payloads: SyntheticResult.payloads,
            renderingMode: .linking,
            downsizeImagesEnabled: false,
            downsizeScaleFactor: 0.25,
            faultCollector: FaultCollector(),
            bundleNames: ["Synthetic"]
        )
        summary.validate()
        return summary
    }

    private func details(_ summary: Summary, _ kind: Fault.Kind) -> [String] {
        summary.faults.filter { $0.kind == kind }.map(\.detail)
    }

    // MARK: A host-app / system-failure crash row

    func testModernShapeOfACrashedRunFaults() {
        // The shape the modern reader produced for the reproduced crash: the
        // bucket carries the row, and the row names the fault.
        let summary = validatedSummary([run(testables: [
            ParsedTestable(targetName: "SampleAppUnitTests", groups: [
                group("System Failures", [
                    testCase("SampleApp (43043) encountered an error"),
                ]),
            ]),
        ])])

        XCTAssertEqual(
            details(summary, .systemFailure),
            ["SampleAppUnitTests: SampleApp (43043) encountered an error"],
            "A system-failure row is direct evidence the run did not complete"
        )
    }

    func testLegacyShapeOfACrashedRunFaults() {
        // The shape the legacy reader produced for the *same* bundle:
        // XCResultKit does not decode the crash row (it is an
        // `ActionTestSummary`, not an `ActionTestMetadata`), so the bucket
        // arrives empty. Keying the rule on the bucket rather than on its rows
        // is the whole reason this bundle faults on both readers — and it is
        // what the two backends' fault details differing does *not* mean:
        // each names the most specific thing its own document holds.
        let summary = validatedSummary([run(testables: [
            ParsedTestable(targetName: "SampleAppUnitTests", groups: [
                group("System Failures", []),
            ]),
        ])])

        XCTAssertEqual(details(summary, .systemFailure), ["SampleAppUnitTests: System Failures"])
    }

    func testNestedSystemFailureGroupIsFound() {
        // Both backends put the bucket directly under the testable today. The
        // walk is recursive anyway: the bucket is Apple's, so a deeper one is
        // still a system failure, and missing a relocated bucket is the worse
        // failure mode for a fault whose whole job is catching truncation.
        let summary = validatedSummary([run(testables: [
            ParsedTestable(targetName: "SampleAppUnitTests", groups: [
                group("All tests", [
                    .group(group("System Failures", [testCase("Host (1) encountered an error")])),
                ]),
            ]),
        ])])

        XCTAssertEqual(
            details(summary, .systemFailure),
            ["SampleAppUnitTests: Host (1) encountered an error"]
        )
    }

    func testOrdinarySuiteNamesAreNotSystemFailures() {
        let summary = validatedSummary([run(testables: [
            ParsedTestable(targetName: "SampleAppUnitTests", groups: [
                group("FirstSuite", [testCase("testOne()")]),
            ]),
        ])])

        XCTAssertEqual(details(summary, .systemFailure), [])
    }

    // MARK: What a missing target is not

    func testSelectedTargetWithNoTestRowsIsNotAFault() {
        // The counterexample that withdrew a second fault kind. An earlier
        // revision flagged any testable holding zero test rows as
        // `emptyPlannedTestable`. This is that shape — and it is what an
        // ordinary `-skip-testing:Target/SuiteA -skip-testing:Target/SuiteB`
        // leaves behind on the legacy reader, which keeps a zero-row
        // `Selected tests` group where the modern node tree prunes the bundle
        // node entirely. Quarantining a flaky suite and sharding a target
        // across CI jobs both produce it, on the default reader, on a run where
        // every test that was planned to run ran. Faulting it made exit 3 mean
        // less, not more.
        //
        // Whole-target loss is caught before the tool sees a bundle, by the
        // per-bundle floors in `scripts/verify_fixtures.sh`; a target lost to a
        // launch trap is caught here, by the system-failure bucket that comes
        // with it.
        let summary = validatedSummary([run(testables: [
            ParsedTestable(targetName: "SampleAppUITests", groups: [
                group("Selected tests", [testCase("testOne()")]),
            ]),
            ParsedTestable(targetName: "SampleAppUnitTests", groups: [
                group("Selected tests", []),
            ]),
        ])])

        XCTAssertEqual(
            summary.faults, [],
            "A selected target with no rows is a skip filter, not degradation"
        )
    }

    func testRunWithNoTestablesAtAllIsNotAFault() {
        // The cardinal rule. A bundle that legitimately contains no testable
        // — `-only-testing` prunes unselected targets from the document on both
        // backends, which is why SanityResults and RetryResults carry one
        // testable and not three — is structural absence, not degradation
        // (#387).
        let summary = validatedSummary([run(testables: [])])

        XCTAssertEqual(summary.faults, [])
    }

    // MARK: Shared post-conditions

    func testTruncationFaultsAreNotDuplicatedAcrossRepeatedValidation() {
        // `validate()` is idempotent for every other fault kind it records; a
        // second call must not double this one either.
        let summary = Summary(
            parsedRuns: [run(testables: [
                ParsedTestable(targetName: "SampleAppUnitTests", groups: [
                    group("System Failures", [testCase("SampleApp (1) encountered an error")]),
                ]),
            ])],
            payloads: SyntheticResult.payloads,
            renderingMode: .linking,
            downsizeImagesEnabled: false,
            downsizeScaleFactor: 0.25,
            faultCollector: FaultCollector(),
            bundleNames: ["Synthetic"]
        )

        summary.validate()
        let afterFirst = summary.faults
        XCTAssertEqual(afterFirst.count, 1, "One system failure")

        summary.validate()

        XCTAssertEqual(
            summary.faults, afterFirst,
            "validate() must not re-record truncation faults on a second call"
        )
    }

    /// Every healthy fixture, through every backend the toolchain can run, must
    /// produce no system failure. These are healthy bundles; a rule that fires
    /// on them is a rule that makes exit 3 meaningless.
    func testHealthyFixturesProduceNoTruncationFaultsOnEitherBackend() throws {
        var backends: [ResultBackend] = [.modern]
        if case .use(.legacy) = ResultBackend.legacy.resolve() {
            backends.append(.legacy)
        }

        for fixture in ["TestResults", "SanityResults", "RetryResults"] {
            let url = try XCTUnwrap(
                Bundle.testBundle.url(forResource: fixture, withExtension: "xcresult")
            )
            for backend in backends {
                let summary = Summary(
                    resultPaths: [url.path],
                    renderingMode: .linking,
                    downsizeImagesEnabled: false,
                    downsizeScaleFactor: 0.25,
                    faultCollector: FaultCollector(),
                    backend: backend
                )
                summary.validate()

                XCTAssertEqual(
                    details(summary, .systemFailure), [],
                    "\(fixture) on \(backend.rawValue): healthy bundle reported a system failure"
                )
            }
        }
    }
}
