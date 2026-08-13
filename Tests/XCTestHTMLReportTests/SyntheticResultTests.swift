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
    func testCoversEveryRenderedStatus() {
        let statuses = SyntheticResult.parsedResult.runs
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
            .flatMap(\.iterations)
            .map(\.status)

        XCTAssertEqual(
            Set(statuses),
            [.passed, .failed, .skipped, .expectedFailure],
            "Every status the renderer draws differently must appear"
        )
    }

    func testCoversRetries() {
        let iterationCounts = SyntheticResult.parsedResult.runs
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
            .map(\.iterations.count)

        XCTAssertTrue(
            iterationCounts.contains { $0 > 1 },
            "At least one test case must have repetitions"
        )
    }

    func testCoversHostileAttachmentFilename() {
        let filenames = SyntheticResult.parsedResult.runs
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
            .flatMap(\.iterations)
            .flatMap(\.activities)
            .flatMap(\.attachments)
            .compactMap(\.filename)

        XCTAssertTrue(
            filenames.contains { $0.contains("\"") && $0.contains("<") },
            "A filename with quotes and angle brackets must be present — it is "
                + "the escaping path the real fixture covers"
        )
    }
}
