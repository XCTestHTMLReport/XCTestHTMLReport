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

    var retryResultsUrl: URL? {
        Bundle.testBundle
            .url(forResource: "RetryResults", withExtension: "xcresult")
    }

    func testMixedStatusFromTestRetries() throws {
        guard let retryResultsUrl = retryResultsUrl else {
            throw XCTSkip("RetryResults.xcresult not found, this likely means Xcode < 13.0")
        }

        let summary = Summary(
            resultPaths: [retryResultsUrl.path],
            renderingMode: .linking,
            downsizeImagesEnabled: false
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
            XCTAssertEqual(texts[0].intGroupMatch("All \\((\\d+)\\)"), 13)
            XCTAssertEqual(texts[1].intGroupMatch("Passed \\((\\d+)\\)"), 7)
            XCTAssertEqual(texts[2].intGroupMatch("Skipped \\((\\d+)\\)"), 1)
            XCTAssertEqual(texts[3].intGroupMatch("Failed \\((\\d+)\\)"), 5)
            XCTAssertEqual(texts[4].intGroupMatch("Mixed \\((\\d+)\\)"), 0)
        }
    }

    func testJunitReportContainsFailures() throws {
        let testResultsUrl = try XCTUnwrap(testResultsUrl)
        let summary = Summary(
            resultPaths: [testResultsUrl.path],
            renderingMode: .linking,
            downsizeImagesEnabled: false
        )
        
        let junitXml = summary.generatedJunitReport(includeRunDestinationInfo: false)
        let parser = try SwiftSoup.parse(junitXml, "", Parser.xmlParser())
        let testcase = try XCTUnwrap(parser.select("testcase[classname=\"FirstSuite\"][name=\"testTwo()\"]").first())
        let failure = try XCTUnwrap(testcase.getElementsByTag("failure").first())
        try XCTAssertNoThrow(failure.attr("message"))
    }
    
    func testJunitReportStepsAreOrdered() throws {
        let testResultsUrl = try XCTUnwrap(testResultsUrl)
        let summary = Summary(
            resultPaths: [testResultsUrl.path],
            renderingMode: .linking,
            downsizeImagesEnabled: false
        )
        
        let junitXml = summary.generatedJunitReport(includeRunDestinationInfo: false)
        let parser = try SwiftSoup.parse(junitXml, "", Parser.xmlParser())
        let testcase = try XCTUnwrap(parser.select("testcase[classname=\"FirstSuite\"][name=\"testTwo()\"]").first())

        let setUpIndex = try XCTUnwrap(testcase.children().firstIndex { $0.ownText().contains("Set Up") })
        let failureIndex = try XCTUnwrap(testcase.children().firstIndex { $0.tagName() == "failure" })
        let tearDownIndex = try XCTUnwrap(testcase.children().firstIndex { $0.ownText().contains("Tear Down") })
        
        XCTAssertLessThan(setUpIndex, failureIndex)
        XCTAssertLessThan(failureIndex, tearDownIndex)
    }
}
