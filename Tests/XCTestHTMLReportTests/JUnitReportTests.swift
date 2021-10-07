//
//  JUnitReportTests.swift
//
//
//  Created by Guillermo Ignacio Enriquez Gutierrez on 2021/01/17.
//

import Foundation
import XCTest
import NDHpple
@testable import XCTestHTMLReportCore

final class JUnitReportTests: XCTestCase {

    func testBasicFunctionality() throws {
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
                        JUnitReport.TestResult(title: "Assertion Failure: <unknown>:0: Application com.example.test is not running", state: .failed)
                    ]
                )]
            )])
        let xml = jUnitReport.xmlString

        let parser = NDHpple(xmlData: xml)

        let testSuitesElem = try XCTUnwrap(parser.peekAtSearch(withQuery: "/*"))
        XCTAssertEqual(testSuitesElem.rawValueOfAttribute(name: "name"), "JUnitReportName&lt;\'&amp;\\&gt;")

        let testSuiteElem = try XCTUnwrap(testSuitesElem.firstChild(forName: "testsuite"))
        XCTAssertEqual(testSuiteElem.rawValueOfAttribute(name: "name"), "JUnitReportTestSuiteName&lt;\'&amp;\\&gt;")
        XCTAssertEqual(testSuiteElem.rawValueOfAttribute(name: "tests"), "1")

        let testCaseElem = try XCTUnwrap(testSuiteElem.firstChild(forName: "testcase"))
        XCTAssertEqual(testCaseElem.rawValueOfAttribute(name: "classname"), "MyClassName&lt;\'&amp;\\&gt;")
        XCTAssertEqual(testCaseElem.rawValueOfAttribute(name: "name"), "MyName&lt;\'&amp;\\&gt;")
        XCTAssertEqual(testCaseElem.rawValueOfAttribute(name: "time"), "0.00") // This needs a fix. Precision is lost not only here but in various places where numbers are used. #177

        let systemOutElem = try XCTUnwrap(testCaseElem.firstChild(forName: "system-out"))
        let systemOutContent = try XCTUnwrap(systemOutElem.children.first)
        XCTAssertEqual(systemOutContent["rawValue"] as? String, "TitleHere&lt;\'&amp;\\&gt;")

        let failureElem = try XCTUnwrap(testCaseElem.firstChild(forName: "failure"))
        XCTAssertEqual(failureElem.rawValueOfAttribute(name: "message"), "Assertion Failure: &lt;unknown&gt;:0: Application com.example.test is not running")
    }

    static var allTests = [
        ("testBasicFunctionality", testBasicFunctionality),
    ]
}
