//
//  MergeDestinationsTests.swift
//
//  `--merge-destinations` (#354): runs on equivalent destinations — parallel
//  testing clones, or bundles merged with `xcresulttool merge` — render as one
//  destination, the way Xcode shows them.
//

import XCTest
@testable import XCTestHTMLReportCore

final class MergeDestinationsTests: XCTestCase {
    /// The synthetic run on a destination of its own: same model and OS as
    /// `SyntheticResult.parsedRun`, different name and identifier, which is
    /// what a parallel testing clone looks like.
    private static func clone(
        named name: String,
        identifier: String,
        targetName: String = "CloneTests",
        logReference: String? = SyntheticResult.parsedRun.logReference
    ) -> ParsedRun {
        let base = SyntheticResult.parsedRun
        return ParsedRun(
            destination: ParsedDestination(
                displayName: name,
                deviceIdentifier: identifier,
                modelName: base.destination.modelName,
                operatingSystemVersion: base.destination.operatingSystemVersion
            ),
            logReference: logReference,
            testables: [ParsedTestable(targetName: targetName, groups: base.testables[0].groups)]
        )
    }

    private static let clones = [
        SyntheticResult.parsedRun,
        clone(
            named: "Clone 1 of Synthetic Device",
            identifier: "00000000-0000-0000-0000-0000000000C1"
        ),
    ]

    private func summary(_ parsedRuns: [ParsedRun], merge: Bool) -> Summary {
        Summary(
            parsedRuns: parsedRuns,
            payloads: SyntheticResult.payloads,
            renderingMode: .linking,
            downsizeImagesEnabled: false,
            downsizeScaleFactor: 0.5,
            bundleNames: ["Synthetic"],
            mergeDestinations: merge
        )
    }

    func testEquivalentDestinationsAreSeparateByDefault() {
        let summary = summary(Self.clones, merge: false)

        XCTAssertEqual(summary.renderedRuns.count, 2)
        XCTAssertTrue(summary.generatedHtmlReport().contains("2 devices"))
    }

    func testEquivalentDestinationsRenderAsOne() throws {
        let summary = summary(Self.clones, merge: true)
        let html = summary.generatedHtmlReport()

        let merged = try XCTUnwrap(summary.renderedRuns.first)
        XCTAssertEqual(summary.renderedRuns.count, 1)
        XCTAssertEqual(
            merged.testSummaries.map(\.testName), ["CloneTests", "SyntheticTests"],
            "every target from every clone must be in the one run, ordered as one run orders them"
        )
        XCTAssertEqual(merged.numberOfTests, summary.runs.map(\.numberOfTests).reduce(0, +))
        XCTAssertEqual(merged.runDestination.name, "Synthetic Model (2 devices)")
        XCTAssertTrue(html.contains("1 device"))
        XCTAssertEqual(html.components(separatedBy: "id=\"tests_").count - 1, 1)
        XCTAssertEqual(html.components(separatedBy: "id=\"logs_").count - 1, 1)
    }

    func testClonesOfOneTargetRenderAsOneTree() throws {
        let target = SyntheticResult.parsedRun.testables[0].targetName
        let summary = summary(
            [
                SyntheticResult.parsedRun,
                Self.clone(
                    named: "Clone 1 of Synthetic Device",
                    identifier: "00000000-0000-0000-0000-0000000000C1",
                    targetName: target
                ),
            ],
            merge: true
        )

        let merged = try XCTUnwrap(summary.renderedRuns.first)
        XCTAssertEqual(merged.testSummaries.map(\.testName), [target])
        XCTAssertEqual(
            merged.testSummaries[0].tests.count,
            summary.runs.map { $0.testSummaries[0].tests.count }.reduce(0, +),
            "the one tree must hold every clone's suites"
        )
    }

    private static func withConfigurations(
        _ configurations: [String?],
        of run: ParsedRun
    ) -> ParsedRun {
        ParsedRun(
            destination: run.destination,
            logReference: run.logReference,
            testables: configurations.map {
                ParsedTestable(
                    targetName: run.testables[0].targetName,
                    configuration: $0,
                    groups: run.testables[0].groups
                )
            }
        )
    }

    private static let targetClone = clone(
        named: "Clone 1 of Synthetic Device",
        identifier: "00000000-0000-0000-0000-0000000000C1",
        targetName: SyntheticResult.parsedRun.testables[0].targetName
    )

    func testEachConfigurationOfATargetStaysItsOwnTree() throws {
        let target = SyntheticResult.parsedRun.testables[0].targetName
        let summary = summary(
            [
                Self.withConfigurations(["A", "B"], of: SyntheticResult.parsedRun),
                Self.withConfigurations(["A", "B"], of: Self.targetClone),
            ],
            merge: true
        )

        let merged = try XCTUnwrap(summary.renderedRuns.first)
        XCTAssertEqual(merged.testSummaries.map(\.testName), [target, target])
        XCTAssertEqual(merged.testSummaries.map(\.configuration), ["A", "B"])
    }

    func testConfigurationsPairByNameNotPosition() throws {
        let summary = summary(
            [
                Self.withConfigurations(["A", "B"], of: SyntheticResult.parsedRun),
                Self.withConfigurations(["B"], of: Self.targetClone),
            ],
            merge: true
        )

        let merged = try XCTUnwrap(summary.renderedRuns.first)
        let groupsPerRun = SyntheticResult.parsedRun.testables[0].groups.count
        XCTAssertEqual(merged.testSummaries.map(\.configuration), ["A", "B"])
        XCTAssertEqual(
            merged.testSummaries.map(\.tests.count), [groupsPerRun, groupsPerRun * 2],
            "the clone's B must join B, not A"
        )
    }

    func testIndistinguishableConfigurationsAreNotPaired() throws {
        let summary = summary(
            [
                Self.withConfigurations([nil, nil], of: SyntheticResult.parsedRun),
                Self.withConfigurations([nil], of: Self.targetClone),
            ],
            merge: true
        )

        let merged = try XCTUnwrap(summary.renderedRuns.first)
        let groupsPerRun = SyntheticResult.parsedRun.testables[0].groups.count
        XCTAssertEqual(
            merged.testSummaries.map(\.tests.count), [groupsPerRun, groupsPerRun, groupsPerRun]
        )
    }

    func testDevicesSharingANameAreCountedByIdentifier() {
        let destinations = [
            SyntheticResult.parsedRun,
            Self.clone(named: "Clone", identifier: "00000000-0000-0000-0000-0000000000C1"),
            Self.clone(named: "Clone", identifier: "00000000-0000-0000-0000-0000000000C2"),
        ]

        let summary = summary(destinations, merge: true)

        XCTAssertEqual(
            summary.renderedRuns.first?.runDestination.name, "Synthetic Model (3 devices)"
        )
    }

    func testMergedLogKeepsEachDestinationsLogUnderItsName() {
        let html = summary(Self.clones, merge: true).generatedHtmlReport()

        XCTAssertTrue(html.contains("==== Synthetic Device ===="))
        XCTAssertTrue(html.contains("==== Clone 1 of Synthetic Device ===="))
    }

    func testDifferentModelsOrOSVersionsStaySeparate() {
        let summary = summary(
            [SyntheticResult.parsedRun, SyntheticResult.secondParsedRun],
            merge: true
        )

        XCTAssertEqual(summary.renderedRuns.count, 2)
    }

    func testOnlyTheHTMLIsMerged() {
        let summary = summary(Self.clones, merge: true)

        XCTAssertEqual(summary.runs.count, 2, "validation and cleanup must still see each run")
        XCTAssertEqual(
            summary.junit(includeRunDestinationInfo: true).suites.count, 2,
            "JUnit keeps one suite per destination"
        )
    }

    func testMergingDoesNotReportTheMergedLogAsUnresolved() {
        let summary = summary(Self.clones, merge: true)

        summary.validate()

        XCTAssertEqual(summary.faults, [])
    }

    func testMergingStillReportsAnOriginalRunsUnresolvedLog() {
        let summary = summary(
            [
                SyntheticResult.parsedRun,
                Self.clone(
                    named: "Clone 1 of Synthetic Device",
                    identifier: "00000000-0000-0000-0000-0000000000C1",
                    logReference: "no-such-log"
                ),
            ],
            merge: true
        )

        summary.validate()

        XCTAssertEqual(summary.faults.map(\.kind), [.unresolvedLog])
    }
}
