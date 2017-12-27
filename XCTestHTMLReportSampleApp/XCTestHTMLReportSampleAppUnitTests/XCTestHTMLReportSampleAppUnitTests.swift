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
}
