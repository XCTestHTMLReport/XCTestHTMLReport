import SwiftSoup
import XCTest
@testable import XCTestHTMLReportCore

final class SanityTests: XCTestCase {
    var sanityResultsUrl: URL? {
        Bundle.testBundle
            .url(forResource: "SanityResults", withExtension: "xcresult")
    }

    func testBasicFunctionality() throws {
        let testResultsUrl = try XCTUnwrap(sanityResultsUrl)
        let summary = Summary(
            resultPaths: [testResultsUrl.path],
            renderingMode: .linking,
            downsizeImagesEnabled: false
        )

        let document = try SwiftSoup.parse(summary.html)

        try XCTContext.runActivity(named: "Test header contain the right number of results") { _ in
            let elements = try XCTUnwrap(
                document
                    .select("div.tests-header > ul:first-of-type > li")
            )
            let texts = try elements.eachText()
            XCTAssertEqual(texts.count, 5)
            XCTAssertEqual(texts[0].intGroupMatch("All \\((\\d+)\\)"), 1)
            XCTAssertEqual(texts[1].intGroupMatch("Passed \\((\\d+)\\)"), 1)
            XCTAssertEqual(texts[2].intGroupMatch("Skipped \\((\\d+)\\)"), 0)
            XCTAssertEqual(texts[3].intGroupMatch("Failed \\((\\d+)\\)"), 0)
            XCTAssertEqual(texts[4].intGroupMatch("Mixed \\((\\d+)\\)"), 0)
        }
    }

    func testRetryFunctionalityJunit() throws {
        guard let testResultsUrl = Bundle.testBundle.url(forResource: "RetryResults", withExtension: "xcresult") else {
            throw XCTSkip("RetryResults.xcresult not found, this likely means Xcode < 13.0")
        }

        let summary = Summary(resultPaths: [testResultsUrl.path], renderingMode: .linking, downsizeImagesEnabled: false)
        let junit = summary.junit(includeRunDestinationInfo: false)

        XCTAssertEqual(junit.failures, 1)
        XCTAssertEqual(junit.suites.count, 1)

        let suite = try XCTUnwrap(junit.suites.first)
        XCTAssertEqual(suite.cases.count, 3)

        let testRetryOnFailure = try XCTUnwrap(suite.cases.first { $0.name == "testRetryOnFailure()" })
        XCTAssertEqual(testRetryOnFailure.state, .mixed)
        assertJunitResults(testRetryOnFailure.results, count: 10, failed: 0, systemErr: 1, systemOut: 2, unknown: 7, skipped: 0)

        let testJustFail = try XCTUnwrap(suite.cases.first { $0.name == "testJustFail()" })
        XCTAssertEqual(testJustFail.state, .failed)
        assertJunitResults(testJustFail.results, count: 8, failed: 1, systemErr: 1, systemOut: 0, unknown: 6, skipped: 0)

        let testJustPass = try XCTUnwrap(suite.cases.first { $0.name == "testJustPass()" })
        XCTAssertEqual(testJustPass.state, .passed)
        assertJunitResults(testJustPass.results, count: 4, failed: 0, systemErr: 0, systemOut: 0, unknown: 4, skipped: 0)
    }

    func testWithDeviceInformation() throws {
        guard let testResultsUrl = Bundle.testBundle.url(forResource: "RetryResults", withExtension: "xcresult") else {
            throw XCTSkip("RetryResults.xcresult not found, this likely means Xcode < 13.0")
        }

        let summary = Summary(resultPaths: [testResultsUrl.path], renderingMode: .linking, downsizeImagesEnabled: false)
        let junit = summary.junit(includeRunDestinationInfo: true).xmlString.components(separatedBy: .newlines)

        let suiteString = try XCTUnwrap(junit.first { $0.contains("<testsuite name='SampleAppUITests") })
        let testCaseString = try XCTUnwrap(junit.first { $0.contains("<testcase classname='RetryTests") })

        try XCTAssertContains(suiteString, "name='SampleAppUITests - iPhone 8 - 15.2'")
        try XCTAssertContains(testCaseString, "name='RetryTests - iPhone 8 - 15.2'")
    }

    func testWithoutDeviceInformation() throws {
        guard let testResultsUrl = Bundle.testBundle.url(forResource: "RetryResults", withExtension: "xcresult") else {
            throw XCTSkip("RetryResults.xcresult not found, this likely means Xcode < 13.0")
        }

        let summary = Summary(resultPaths: [testResultsUrl.path], renderingMode: .linking, downsizeImagesEnabled: false)
        let junit = summary.junit(includeRunDestinationInfo: false).xmlString.components(separatedBy: .newlines)

        let suiteString = try XCTUnwrap(junit.first { $0.contains("<testsuite name='SampleAppUITests") })
        let testCaseString = try XCTUnwrap(junit.first { $0.contains("<testcase classname='RetryTests") })

        try XCTAssertContains(suiteString, "name='SampleAppUITests'")
        try XCTAssertContains(testCaseString, "name='RetryTests'")
    }
}

private extension SanityTests {
    func assertJunitResults(
        _ results: [JUnitReport.TestResult],
        count: Int,
        failed: Int,
        systemErr: Int,
        systemOut: Int,
        unknown: Int,
        skipped: Int
    ) {
        XCTAssertEqual(results.count, count)
        XCTAssertEqual(results.filter({ $0.state == .failed }).count, failed)
        XCTAssertEqual(results.filter({ $0.state == .systemErr }).count, systemErr)
        XCTAssertEqual(results.filter({ $0.state == .systemOut }).count, systemOut)
        XCTAssertEqual(results.filter({ $0.state == .unknown }).count, unknown)
        XCTAssertEqual(results.filter({ $0.state == .skipped }).count, skipped)
        XCTAssertEqual(count, failed + systemErr + systemOut + unknown + skipped)
    }
}
