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

final class SummaryTests: XCTestCase {
    func testRetryFunctionality() throws {
        guard let testResultsUrl = Bundle.testBundle.url(
            forResource: "RetryResults",
            withExtension: "xcresult"
        ) else {
            throw XCTSkip("RetryResults.xcresult not found, this likely means Xcode < 13.0")
        }

        let summary = Summary(
            resultPaths: [testResultsUrl.path],
            renderingMode: .linking,
            downsizeImagesEnabled: false
        )
        let parser = try SwiftSoup.parse(summary.html)

        try XCTContext.runActivity(named: "blah", block: { _ in
            let elements = try XCTUnwrap(parser.select("div.tests-header > ul:first-of-type > li"))
            let texts = try elements.eachText()

            XCTAssertEqual(texts[0].intGroupMatch("All \\((\\d+)\\)"), 2)
        })
    }
}
