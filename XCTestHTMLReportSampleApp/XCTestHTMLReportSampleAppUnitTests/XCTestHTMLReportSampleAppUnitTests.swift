//
//  XCTestHTMLReportSampleAppUnitTests.swift
//  XCTestHTMLReportSampleAppUnitTests
//
//  Created by Titouan van Belle on 22.12.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import XCTest

class XCTestHTMLReportSampleAppUnitTests: XCTestCase
{
    func testFailure()
    {
        XCTAssert(false, "Test failed")
    }

    func testSuccess()
    {
        XCTAssert(true, "Test succeeded")
    }
    
    func testSkipped() throws {
        // This requires Xcode 11.4 and later
        let letsSkipThis = true
        try XCTSkipIf(letsSkipThis, "Test skipped")
    }
}
