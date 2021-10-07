import XCTest

import XCTestHTMLReportTests

var tests = [XCTestCaseEntry]()
tests += XCTestHTMLReportTests.allTests()
XCTMain(tests)
