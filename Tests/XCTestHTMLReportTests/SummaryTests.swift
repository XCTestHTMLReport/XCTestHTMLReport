//
//  SummaryTests.swift
//
//
//  Created by Guillermo Ignacio Enriquez Gutierrez on 2020/10/11.
//

import Foundation
import XCTest
import NDHpple
@testable import XCTestHTMLReportCore

final class SummaryTests: XCTestCase {

    func testBasicFunctionality() throws {
        let testResultsUrl = try XCTUnwrap(Bundle.testBundle.url(forResource: "TestResults", withExtension: "xcresult"))
        let summary = Summary(resultPaths: [testResultsUrl.path], renderingMode: .linking, downsizeImagesEnabled: false)
        let html = summary.html
        let parser = NDHpple(htmlData: html)

        try XCTContext.runActivity(named: "Test header contain the right number of results") { _ in
            let uls = try XCTUnwrap(parser.peekAtSearch(withQuery: "//div[@class='tests-header']/ul"))
            let texts = uls.children.filter { $0.name == "li" }.compactMap { $0.text }
            XCTAssertEqual(texts[0].intGroupMatch("All \\((\\d+)\\)"), 13)
            XCTAssertEqual(texts[1].intGroupMatch("Passed \\((\\d+)\\)"), 7)
            XCTAssertEqual(texts[2].intGroupMatch("Skipped \\((\\d+)\\)"), 1)
            XCTAssertEqual(texts[3].intGroupMatch("Failed \\((\\d+)\\)"), 5)
        }
    }

    static var allTests = [
        ("testBasicFunctionality", testBasicFunctionality),
    ]
    
    func testRetryFunctionality() throws {
        guard let testResultsUrl = Bundle.testBundle.url(forResource: "RetryResults", withExtension: "xcresult") else {
            throw XCTSkip("RetryResults.xcresult not found, this likely means Xcode < 13.0")
        }

        let summary = Summary(resultPaths: [testResultsUrl.path], renderingMode: .linking, downsizeImagesEnabled: false)
        let html = summary.html
        let parser = NDHpple(htmlData: html)
        
        try XCTContext.runActivity(named: "blah", block: { _ in
            let uls = try XCTUnwrap(parser.peekAtSearch(withQuery: "//div[@class='tests-header']/ul"))
            let texts = uls.children.filter { $0.name == "li" }.compactMap { $0.text }
            XCTAssertEqual(texts[0].intGroupMatch("All \\((\\d+)\\)"), 2)
        })
    }
}
