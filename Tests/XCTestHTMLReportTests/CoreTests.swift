//
//  SummaryTests.swift
//
//
//  Created by Guillermo Ignacio Enriquez Gutierrez on 2020/10/11.
//

import Foundation
import SwiftSoup
import XCTest
@testable import XCTestHTMLReportCore

final class CoreTests: XCTestCase {
    var testResultsUrl: URL? {
        Bundle.testBundle
            .url(forResource: "TestResults", withExtension: "xcresult")
    }

    func testMixedStatusFromTestRetries() throws {
        let retryResultsUrl = try getRetryResultsUrl()

        let summary = Summary(
            resultPaths: [retryResultsUrl.path],
            renderingMode: .linking,
            downsizeImagesEnabled: false,
            downsizeScaleFactor: 0.5
        )

        let document = try SwiftSoup.parse(summary.html)

        try XCTContext.runActivity(named: "Reports \"Mixed\" status", block: { _ in
            let elements = try XCTUnwrap(
                document
                    .select("div.tests-header > ul:first-of-type > li")
            )
            let texts = try elements.eachText()
            XCTAssertEqual(texts.count, 5)
            XCTAssertEqual(texts[0].intGroupMatch("All \\((\\d+)\\)"), 3)
            XCTAssertEqual(texts[1].intGroupMatch("Passed \\((\\d+)\\)"), 1)
            XCTAssertEqual(texts[2].intGroupMatch("Skipped \\((\\d+)\\)"), 0)
            XCTAssertEqual(texts[3].intGroupMatch("Failed \\((\\d+)\\)"), 1)
            XCTAssertEqual(texts[4].intGroupMatch("Mixed \\((\\d+)\\)"), 1)
        })
    }

    func testResultStatusCount() throws {
        let testResultsUrl = try XCTUnwrap(testResultsUrl)
        let summary = Summary(
            resultPaths: [testResultsUrl.path],
            renderingMode: .linking,
            downsizeImagesEnabled: false,
            downsizeScaleFactor: 0.5
        )

        let document = try SwiftSoup.parse(summary.html)

        try XCTContext.runActivity(named: "Test header contain the right number of results") { _ in
            let elements = try XCTUnwrap(
                document
                    .select("div.tests-header > ul:first-of-type > li")
            )
            let texts = try elements.eachText()
            XCTAssertEqual(texts.count, 5)
            XCTAssertEqual(texts[0].intGroupMatch("All \\((\\d+)\\)"), 13)
            XCTAssertEqual(texts[1].intGroupMatch("Passed \\((\\d+)\\)"), 7)
            XCTAssertEqual(texts[2].intGroupMatch("Skipped \\((\\d+)\\)"), 1)
            XCTAssertEqual(texts[3].intGroupMatch("Failed \\((\\d+)\\)"), 5)
            XCTAssertEqual(texts[4].intGroupMatch("Mixed \\((\\d+)\\)"), 0)
        }
    }

    func testRetryFunctionalityJunit() throws {
        let retryResultsUrl = try getRetryResultsUrl()

        let summary = Summary(
            resultPaths: [retryResultsUrl.path],
            renderingMode: .linking,
            downsizeImagesEnabled: false,
            downsizeScaleFactor: 0.5
        )
        let junit = summary.junit(includeRunDestinationInfo: false)

        XCTAssertEqual(junit.failures, 1)
        XCTAssertEqual(junit.suites.count, 1)

        let suite = try XCTUnwrap(junit.suites.first)
        XCTAssertEqual(suite.cases.count, 3)

        let testRetryOnFailure = try XCTUnwrap(
            suite.cases
                .first { $0.name == "testRetryOnFailure()" }
        )
        XCTAssertEqual(testRetryOnFailure.state, .mixed)
        assertJunitResults(
            testRetryOnFailure.results,
            count: 10,
            failed: 0,
            systemErr: 1,
            systemOut: 2,
            unknown: 7,
            skipped: 0
        )

        let testJustFail = try XCTUnwrap(suite.cases.first { $0.name == "testJustFail()" })
        XCTAssertEqual(testJustFail.state, .failed)
        assertJunitResults(
            testJustFail.results,
            count: 8,
            failed: 1,
            systemErr: 1,
            systemOut: 0,
            unknown: 6,
            skipped: 0
        )

        let testJustPass = try XCTUnwrap(suite.cases.first { $0.name == "testJustPass()" })
        XCTAssertEqual(testJustPass.state, .passed)
        assertJunitResults(
            testJustPass.results,
            count: 4,
            failed: 0,
            systemErr: 0,
            systemOut: 0,
            unknown: 4,
            skipped: 0
        )
    }

    func testWithDeviceInformation() throws {
        let retryResultsUrl = try getRetryResultsUrl()

        let summary = Summary(
            resultPaths: [retryResultsUrl.path],
            renderingMode: .linking,
            downsizeImagesEnabled: false,
            downsizeScaleFactor: 0.5
        )
        let junit = summary.junit(includeRunDestinationInfo: true).xmlString
            .components(separatedBy: .newlines)

        let suiteString = try XCTUnwrap(
            junit
                .first { $0.contains("<testsuite name='SampleAppUITests") }
        )
        let testCaseString = try XCTUnwrap(
            junit
                .first { $0.contains("<testcase classname='RetryTests") }
        )

        let suiteRegex = #"name='SampleAppUITests - iPhone \d+ - \d+.\d"#
        let testCaseRegex = #"classname='RetryTests - iPhone \d+ - \d+.\d"#
        XCTAssertNotNil(suiteString.range(of: suiteRegex, options: .regularExpression))
        XCTAssertNotNil(testCaseString.range(of: testCaseRegex, options: .regularExpression))
    }

    func testWithoutDeviceInformation() throws {
        let retryResultsUrl = try getRetryResultsUrl()

        let summary = Summary(
            resultPaths: [retryResultsUrl.path],
            renderingMode: .linking,
            downsizeImagesEnabled: false,
            downsizeScaleFactor: 0.5
        )
        let junit = summary.junit(includeRunDestinationInfo: false).xmlString
            .components(separatedBy: .newlines)

        let suiteString = try XCTUnwrap(
            junit
                .first { $0.contains("<testsuite name='SampleAppUITests") }
        )
        let testCaseString = try XCTUnwrap(
            junit
                .first { $0.contains("<testcase classname='RetryTests") }
        )

        try XCTAssertContains(suiteString, "name='SampleAppUITests'")
        try XCTAssertContains(testCaseString, "name='RetryTests'")
    }
}

private extension CoreTests {
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
        XCTAssertEqual(results.filter { $0.state == .failed }.count, failed)
        XCTAssertEqual(results.filter { $0.state == .systemErr }.count, systemErr)
        XCTAssertEqual(results.filter { $0.state == .systemOut }.count, systemOut)
        XCTAssertEqual(results.filter { $0.state == .unknown }.count, unknown)
        XCTAssertEqual(results.filter { $0.state == .skipped }.count, skipped)
        XCTAssertEqual(count, failed + systemErr + systemOut + unknown + skipped)
    }

    func getRetryResultsUrl() throws -> URL {
        if let retryResultsUrl = Bundle.testBundle.url(
            forResource: "RetryResults",
            withExtension: "xcresult"
        ) {
            return retryResultsUrl
        }

        throw XCTSkip("RetryResults.xcresult not found, this likely means Xcode < 13.0")
    }
}
