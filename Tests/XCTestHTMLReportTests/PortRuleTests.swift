//
//  PortRuleTests.swift
//
//  Direct unit tests for the port-level rules both readers share. These are
//  the rules the differential relies on to make the backends agree by
//  construction, so each is pinned in isolation with crafted inputs rather
//  than only through fixture renders.
//

import Foundation
import XCTest
@testable import XCTestHTMLReportCore

final class PortRuleTests: XCTestCase {
    // MARK: - ParsedActivity.interleavingFailureRows

    private func activity(
        _ title: String, start: Date?, isFailure: Bool = false
    ) -> ParsedActivity {
        ParsedActivity(
            title: title, isFailure: isFailure, start: start, attachments: [],
            subActivities: []
        )
    }

    private let epoch = Date(timeIntervalSince1970: 1786584757)

    func testInterleaveOrdersByStart() {
        let merged = ParsedActivity.interleavingFailureRows(
            activities: [
                activity("first", start: epoch),
                activity("third", start: epoch.addingTimeInterval(2)),
            ],
            failureRows: [activity("second", start: epoch.addingTimeInterval(1), isFailure: true)]
        )
        XCTAssertEqual(merged.map(\.title), ["first", "second", "third"])
    }

    /// The tie this exists for is hit in practice, not hypothetically: at the
    /// format's millisecond granularity an assertion's timestamp routinely
    /// equals its enclosing activity's start — measured on
    /// `testWithSpecialChars()` (activity and failure both at …37.696) and on
    /// `ThirdSuite/testOne()` (failure at …37.873 tying two activities).
    func testInterleaveBreaksEqualStartsActivityFirst() {
        let merged = ParsedActivity.interleavingFailureRows(
            activities: [activity("the activity", start: epoch)],
            failureRows: [activity("the failure", start: epoch, isFailure: true)]
        )
        XCTAssertEqual(merged.map(\.title), ["the activity", "the failure"])
    }

    /// A row with no timestamp is an unpositioned annotation (appended failure
    /// message, skip notice) and sorts after the whole timeline — not before
    /// it, which is where a naive `nil -> .distantPast` would put it.
    func testInterleaveOrdersNilStartsLast() {
        let merged = ParsedActivity.interleavingFailureRows(
            activities: [activity("timed", start: epoch)],
            failureRows: [
                activity("skip notice", start: nil, isFailure: true),
                activity("timed failure", start: epoch, isFailure: true),
            ]
        )
        XCTAssertEqual(
            merged.map(\.title), ["timed", "timed failure", "skip notice"]
        )
    }

    /// The order must be *total*: identical rows fall back to source index,
    /// so the result is one deterministic sequence, not whatever the sort
    /// algorithm happens to do with incomparable elements. The comparator
    /// this helper replaced was non-total once before (#443).
    func testInterleaveIsTotalOnIdenticalRows() {
        let rows = (0 ..< 8).map { index in
            activity("failure \(index)", start: epoch, isFailure: true)
        }
        let merged = ParsedActivity.interleavingFailureRows(
            activities: [], failureRows: rows
        )
        XCTAssertEqual(merged.map(\.title), rows.map(\.title))
    }

    // MARK: - LegacyResultReader.mergingArgumentExecutions

    private func iteration(
        number: Int?, status: ParsedStatus, duration: TimeInterval = 1
    ) -> ParsedIteration {
        ParsedIteration(
            iterationNumber: number, status: status, duration: duration,
            activities: [activity("a", start: epoch)]
        )
    }

    func testArgumentExecutionsMergeIntoOneIteration() {
        let merged = LegacyResultReader.mergingArgumentExecutions([
            iteration(number: nil, status: .passed, duration: 0.25),
            iteration(number: nil, status: .passed, duration: 0.5),
            iteration(number: nil, status: .passed, duration: 0.25),
        ])
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged[0].status, .passed)
        XCTAssertEqual(merged[0].duration, 1.0, accuracy: 0.0001)
        XCTAssertEqual(
            merged[0].activities.count, 3,
            "Activities concatenate in source order"
        )
    }

    func testArgumentExecutionMergeReportsFailureWhenAnyArgumentFails() {
        let merged = LegacyResultReader.mergingArgumentExecutions([
            iteration(number: nil, status: .passed),
            iteration(number: nil, status: .failed),
        ])
        XCTAssertEqual(merged.map(\.status), [.failed])
    }

    /// True retries carry `repetitionPolicySummary` numbers, and must keep
    /// their iteration structure — this is the boundary that protects
    /// `RetryResults`' mixed-status rendering.
    func testNumberedRepetitionsAreNeverMerged() {
        let retries = [
            iteration(number: 1, status: .failed),
            iteration(number: 2, status: .passed),
        ]
        XCTAssertEqual(
            LegacyResultReader.mergingArgumentExecutions(retries).count, 2
        )
    }

    // MARK: - ParsedAttachment.exportFileName

    func testExportFileNameIsPayloadIdPlusExtension() {
        XCTAssertEqual(
            ParsedAttachment.exportFileName(
                payloadId: "0~qL1-DW_x8=", filenameExtension: "mp4"
            ),
            "0~qL1-DW_x8=.mp4"
        )
        XCTAssertEqual(
            ParsedAttachment.exportFileName(payloadId: "0~abc", filenameExtension: nil),
            "0~abc"
        )
        XCTAssertEqual(
            ParsedAttachment.exportFileName(payloadId: "a/b", filenameExtension: "txt"),
            "a_b.txt",
            "A path separator in a future id shape must not escape the bundle directory"
        )
    }
}
