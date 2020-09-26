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

    func testWithLogAttachment() throws {
        let logData = "log1\nlog2\nlog3".data(using: .utf8)!
        let attachment = XCTAttachment.init(data: logData, uniformTypeIdentifier: "com.apple.log")
        attachment.name = "myLogFile"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testWithLogAttachmentWithoutName() throws {
        let logData = "log4\nlog5\nlog6".data(using: .utf8)!
        let attachment = XCTAttachment.init(data: logData, uniformTypeIdentifier: "com.apple.log")
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
