//
//  TruncationFaultTests.swift
//
//  The two faults that catch a run which stopped early (#478).
//
//  On the Xcode 27 beta the sample app trapped at launch, `SampleAppUnitTests`
//  never ran, and `xchtmlreport` rendered 10 of 21 tests, printed "Report
//  successfully created", and exited 0. A report that claims completeness while
//  silently dropping 57% of the suite is precisely what the fault machinery
//  exists to prevent.
//
//  Both signals are read off `ParsedResult`, the model *both* readers produce,
//  so there is one implementation and it cannot drift between backends — the
//  same seam `unresolvedLog` uses. The shapes were not guessed: the crash was
//  reproduced on Xcode 26.2 stable by trapping in the host app's
//  `didFinishLaunchingWithOptions`, and both backends were dumped. They agree
//  exactly, which is what makes a name-keyed rule defensible here:
//
//    legacy  ActionTestSummaryGroup name='System Failures'
//              └ ActionTestSummary  name='SampleApp (43043) encountered an error'
//    modern  Test Suite            name='System Failures'
//              └ Test Case         name='SampleApp (43043) encountered an error'
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

    // MARK: An empty but planned testable

    func testTestableWithNoTestRowsIsAFault() {
        // The #478 shape: the target is in the bundle — it was planned, it was
        // meant to run — and produced nothing.
        let summary = validatedSummary([run(testables: [
            ParsedTestable(targetName: "SampleAppUITests", groups: [
                group("FirstSuite", [testCase("testOne()")]),
            ]),
            ParsedTestable(targetName: "SampleAppUnitTests", groups: []),
        ])])

        XCTAssertEqual(
            details(summary, .emptyPlannedTestable), ["SampleAppUnitTests"],
            "A testable present in the bundle with no test rows must be reported"
        )
    }

    func testTestableWhoseGroupsAreAllEmptyIsAFault() {
        // The other way the same loss arrives: the group survived, its rows
        // did not. The beta's `--json` showed exactly this — `"children": []`.
        let summary = validatedSummary([run(testables: [
            ParsedTestable(targetName: "SampleAppUnitTests", groups: [
                group("SwiftTestingSuite", []),
            ]),
        ])])

        XCTAssertEqual(details(summary, .emptyPlannedTestable), ["SampleAppUnitTests"])
    }

    func testDeeplyNestedTestRowsAreNotAFault() {
        // The counter has to see through nesting, or every suite-inside-a-suite
        // target would be reported as empty.
        let summary = validatedSummary([run(testables: [
            ParsedTestable(targetName: "SampleAppUnitTests", groups: [
                group("All tests", [.group(group("Outer", [
                    .group(group("Inner", [testCase("testDeep()")])),
                ]))]),
            ]),
        ])])

        XCTAssertEqual(details(summary, .emptyPlannedTestable), [])
    }

    func testRunWithNoTestablesAtAllIsNotAFault() {
        // The cardinal rule. A bundle that legitimately contains no testable
        // — `-only-testing` prunes unselected targets from the document on both
        // backends, which is why SanityResults and RetryResults carry one
        // testable and not three — is structural absence, not degradation.
        // Only a target that IS there and produced nothing is a loss (#387).
        let summary = validatedSummary([run(testables: [])])

        XCTAssertEqual(details(summary, .emptyPlannedTestable), [])
    }

    // MARK: A host-app / system-failure crash row

    func testModernShapeOfACrashedRunFaults() {
        // The shape the modern reader produced for the reproduced crash: the
        // bucket carries the row, so the testable is not empty and only the
        // system-failure signal fires.
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
        XCTAssertEqual(details(summary, .emptyPlannedTestable), [])
    }

    func testLegacyShapeOfACrashedRunFaults() {
        // The shape the legacy reader produced for the *same* bundle:
        // XCResultKit does not decode the crash row (it is an
        // `ActionTestSummary`, not an `ActionTestMetadata`), so the bucket
        // arrives empty. Keying the rule on the bucket rather than on its rows
        // is what makes this fault too — and an empty bucket also means the
        // testable holds no test rows, so both signals fire, each truthfully.
        let summary = validatedSummary([run(testables: [
            ParsedTestable(targetName: "SampleAppUnitTests", groups: [
                group("System Failures", []),
            ]),
        ])])

        XCTAssertEqual(details(summary, .systemFailure), ["SampleAppUnitTests: System Failures"])
        XCTAssertEqual(details(summary, .emptyPlannedTestable), ["SampleAppUnitTests"])
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

    // MARK: Shared post-conditions

    func testTruncationFaultsAreNotDuplicatedAcrossRepeatedValidation() {
        // `validate()` is idempotent for every other fault kind it records; a
        // second call must not double these either.
        let summary = Summary(
            parsedRuns: [run(testables: [
                ParsedTestable(targetName: "SampleAppUnitTests", groups: [
                    group("System Failures", [testCase("SampleApp (1) encountered an error")]),
                ]),
                ParsedTestable(targetName: "SampleAppUITests", groups: []),
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
        XCTAssertEqual(afterFirst.count, 2, "One empty testable and one system failure")

        summary.validate()

        XCTAssertEqual(
            summary.faults, afterFirst,
            "validate() must not re-record truncation faults on a second call"
        )
    }

    /// Every fixture, through every backend the toolchain can run, must produce
    /// neither fault. These are healthy bundles; a rule that fires on them is a
    /// rule that makes exit 3 meaningless.
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
                    details(summary, .emptyPlannedTestable), [],
                    "\(fixture) on \(backend.rawValue): healthy bundle reported an empty testable"
                )
                XCTAssertEqual(
                    details(summary, .systemFailure), [],
                    "\(fixture) on \(backend.rawValue): healthy bundle reported a system failure"
                )
            }
        }
    }
}
