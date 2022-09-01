//
//  JUnitReportTests.swift
//
//
//  Created by Guillermo Ignacio Enriquez Gutierrez on 2021/01/17.
//

import Foundation
import SwiftSoup
import XCTest
@testable import XCTestHTMLReportCore

final class JUnitReportTests: XCTestCase {
    let jUnitReport = JUnitReport(
        name: "JUnitReportName<'&\\>",
        suites: [JUnitReport.TestSuite(
            name: "JUnitReportTestSuiteName<'&\\>",
            tests: 1,
            cases: [JUnitReport.TestCase(
                classname: "MyClassName<'&\\>",
                name: "MyName<'&\\>",
                time: 0.002,
                state: .failed,
                results: [
                    JUnitReport.TestResult(title: "TitleHere<'&\\>", state: .systemOut),
                    JUnitReport.TestResult(title: "SystemErrorHere<'&\\>", state: .systemErr),
                    JUnitReport.TestResult(
                        title: "Assertion Failure: <unknown>:0: Application com.example.test is not running",
                        state: .failed
                    ),
                ]
            )]
        )]
    )

    func testXmlTreeLayoutAndAttributes() throws {
        let parser = try SwiftSoup.parse(jUnitReport.xmlString, "", Parser.xmlParser())
        print(parser)

        let testSuitesElem = try XCTUnwrap(parser.getElementsByTag("testsuites").first())
        let name = try testSuitesElem.attr("name")
        XCTAssertEqual(Entities.escape(name), "JUnitReportName&lt;\'&amp;\\&gt;")

        let testSuiteElem = testSuitesElem.child(0)
        let suiteName = try testSuiteElem.attr("name")
        let tests = try testSuiteElem.attr("tests")
        XCTAssertEqual(Entities.escape(suiteName), "JUnitReportTestSuiteName&lt;\'&amp;\\&gt;")
        XCTAssertEqual(tests, "1")

        let testCaseElem = testSuiteElem.child(0)
        let testCaseName = try testCaseElem.attr("name")
        let testCaseClassName = try testCaseElem.attr("classname")
        let testCaseTime = try testCaseElem.attr("time")

        XCTAssertEqual(Entities.escape(testCaseName), "MyName&lt;\'&amp;\\&gt;")
        XCTAssertEqual(Entities.escape(testCaseClassName), "MyClassName&lt;\'&amp;\\&gt;")
        // FIXME: #177 This needs a fix. Precision is lost not only here but in various places where numbers are used.
        XCTAssertEqual(testCaseTime, "0.00")

        let systemOutElem = try XCTUnwrap(testCaseElem.getElementsByTag("system-out").first)
        let systemOutText = try systemOutElem.text()
        XCTAssertEqual(Entities.escape(systemOutText), "TitleHere&lt;\'&amp;\\&gt;")

        let systemErrElem = try XCTUnwrap(testCaseElem.getElementsByTag("system-err").first)
        let systemErrText = try systemErrElem.text()
        XCTAssertEqual(Entities.escape(systemErrText), "SystemErrorHere&lt;\'&amp;\\&gt;")

        let failureElem = try XCTUnwrap(testCaseElem.getElementsByTag("failure").first)
        let failureMessage = try failureElem.attr("message")
        XCTAssertEqual(
            Entities.escape(failureMessage),
            "Assertion Failure: &lt;unknown&gt;:0: Application com.example.test is not running"
        )
    }
}
