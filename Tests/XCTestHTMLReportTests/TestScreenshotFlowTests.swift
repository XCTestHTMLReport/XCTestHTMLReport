//
//  TestScreenshotFlowTests.swift
//

import XCTest
@testable import XCTestHTMLReportCore

final class TestScreenshotFlowTests: XCTestCase {
    /// Five activities, each carrying one screenshot.
    private func fiveScreenshotActivities() -> [Activity] {
        SyntheticResult.activities(
            (1 ... 5).map { index in
                SyntheticResult.activity(
                    title: "Activity \(index)",
                    attachments: [SyntheticResult.pngAttachment()]
                )
            }
        )
    }

    func testTailCountIsHonoured() throws {
        let flow = try XCTUnwrap(
            TestScreenshotFlow(activities: fiveScreenshotActivities(), tailCount: 5)
        )
        XCTAssertEqual(
            flow.screenshotsTail.count, 5,
            "tailCount: 5 must yield five tail screenshots, not the hardcoded 3"
        )
    }

    func testTailCountDefaultsToThree() throws {
        let flow = try XCTUnwrap(
            TestScreenshotFlow(activities: fiveScreenshotActivities())
        )
        XCTAssertEqual(flow.screenshotsTail.count, 3)
    }

    func testTailAndFlowUseDistinctClassNames() throws {
        let flow = try XCTUnwrap(
            TestScreenshotFlow(activities: fiveScreenshotActivities())
        )
        XCTAssertEqual(Set(flow.screenshots.map(\.className)), ["screenshot-flow"])
        XCTAssertEqual(Set(flow.screenshotsTail.map(\.className)), ["screenshot-tail"])
    }

    func testNilWhenNoScreenshots() {
        let activities = SyntheticResult.activities([
            SyntheticResult.activity(title: "No attachments"),
        ])
        XCTAssertNil(TestScreenshotFlow(activities: activities))
    }
}
