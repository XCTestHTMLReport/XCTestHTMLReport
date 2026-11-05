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
    private static func clone(named name: String, identifier: String) -> ParsedRun {
        let base = SyntheticResult.parsedRun
        return ParsedRun(
            destination: ParsedDestination(
                displayName: name,
                deviceIdentifier: identifier,
                modelName: base.destination.modelName,
                operatingSystemVersion: base.destination.operatingSystemVersion
            ),
            logReference: base.logReference,
            testables: [ParsedTestable(targetName: "CloneTests", groups: base.testables[0].groups)]
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
}
