//
//  StatusAggregationTests.swift
//
//  What a suite row shows when its children disagree, pinned with crafted
//  inputs rather than through a fixture. `TestGroup.status` reduces a whole
//  subtree to one value, and the cases worth pinning are the ones no sample
//  app happens to produce — a fixture-only test can assert the aggregate the
//  fixtures make, which is not the same thing.
//

import Foundation
import XCTest
@testable import XCTestHTMLReportCore

final class StatusAggregationTests: XCTestCase {
    private func suite(_ statuses: [ParsedStatus]) -> TestGroup {
        TestGroup(
            group: ParsedGroup(
                name: "Suite",
                identifier: "Suite",
                duration: 0,
                children: statuses.enumerated().map { index, status in
                    .testCase(ParsedTestCase(
                        name: "test\(index)()",
                        identifier: "Suite/test\(index)()",
                        arguments: [],
                        executionCount: 1,
                        iterations: [ParsedIteration(
                            iterationNumber: nil,
                            status: status,
                            duration: 0,
                            activities: []
                        )]
                    ))
                }
            ),
            identifierPath: .root,
            // The stand-in FaultReportingTests uses: a bundle that is not
            // there, so no payload export is even attempted.
            file: ResultFile(
                url: URL(fileURLWithPath: NSTemporaryDirectory() + "/DoesNotExist.xcresult"),
                faultCollector: FaultCollector()
            ),
            renderingMode: .linking,
            downsizeImagesEnabled: false,
            downsizeScaleFactor: 0.25
        )
    }

    /// The case #439 nearly left behind.
    ///
    /// `TestGroup.status` walks a fixed precedence list, and a new `Status` is
    /// only half-added until it appears there: without it, a suite whose every
    /// test is an expected failure fell through to `.unknown` — the one value
    /// that means "we could not tell" — while every row inside it said
    /// otherwise. Nothing would have caught it, because group rows draw no
    /// status glyph yet and no fixture builds such a suite.
    func testSuiteOfExpectedFailuresIsNotUnknown() {
        let group = suite([.expectedFailure, .expectedFailure])
        XCTAssertEqual(
            group.subTests.map(\.status), [.expectedFailure, .expectedFailure],
            "Precondition: the rows themselves carry the state"
        )
        XCTAssertEqual(group.status, .expectedFailure)
        XCTAssertEqual(group.status.cssClass, "expected-failure")
    }

    /// Expected failure sits *last* in the precedence list, so it never masks
    /// an outcome the reader is meant to act on.
    func testRealOutcomesOutrankAnExpectedFailure() {
        XCTAssertEqual(suite([.expectedFailure, .failed]).status, .failure)
        XCTAssertEqual(suite([.expectedFailure, .skipped]).status, .skipped)
    }

    /// An expected failure is still not a pass: the all-passed shortcut runs
    /// before the precedence list and must not swallow it.
    func testAnExpectedFailureKeepsASuiteOffTheAllPassedPath() {
        XCTAssertEqual(suite([.passed, .passed]).status, .success)
        XCTAssertEqual(suite([.passed, .expectedFailure]).status, .expectedFailure)
    }
}
