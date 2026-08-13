//
//  SyntheticResultTests.swift
//
//  The fixture is the shared input to every layer below it, so its shape is
//  asserted rather than assumed. A fixture that silently stops covering
//  `expectedFailure` would leave a whole rendered state untested with no
//  failing test to show for it.
//

import XCTest
@testable import XCTestHTMLReportCore

final class SyntheticResultTests: XCTestCase {
    /// Every `ParsedTestCase` in the fixture, flattened out of the
    /// run/testable/group/child tree. Shared by all three tests below so the
    /// extraction chain — which `ParsedNode` requires because a group's
    /// children mix `.group` and `.testCase` cases — is written once.
    private func allTestCases() -> [ParsedTestCase] {
        SyntheticResult.parsedResult.runs
            .flatMap(\.testables)
            .flatMap(\.groups)
            .flatMap { group -> [ParsedTestCase] in
                group.children.compactMap {
                    if case let .testCase(testCase) = $0 {
                        return testCase
                    }
                    return nil
                }
            }
    }

    func testCoversEveryRenderedStatus() {
        let statuses = allTestCases()
            .flatMap(\.iterations)
            .map(\.status)

        XCTAssertEqual(
            Set(statuses),
            [.passed, .failed, .skipped, .expectedFailure],
            "Every status the renderer draws differently must appear"
        )
    }

    func testCoversRetries() {
        let iterationCounts = allTestCases()
            .map(\.iterations.count)

        XCTAssertTrue(
            iterationCounts.contains { $0 > 1 },
            "At least one test case must have repetitions"
        )
    }

    func testCoversHostileAttachmentFilename() {
        let filenames = allTestCases()
            .flatMap(\.iterations)
            .flatMap(\.activities)
            .flatMap(\.attachments)
            .compactMap(\.filename)

        XCTAssertTrue(
            filenames.contains {
                $0.contains("\"") && $0.contains("'") && $0.contains("<")
                    && $0.contains(">") && $0.contains("&")
            },
            "A filename with quotes, angle brackets, and an ampersand must be "
                + "present — it is the escaping path the real fixture covers"
        )
    }
}
