//
//  NoAttachementSuite.swift
//  XCUITestHTMLReportSampleAppUITests
//
//  Created by Titouan van Belle on 23.07.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import XCTest

class Suite: XCTestCase {
        
    override func setUp() {
        super.setUp()

        continueAfterFailure = false

        XCUIApplication().launch()
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func testWithoutAttachementOne() {
        let result = true
        XCTAssert(result, "Test \(result ? "succeeded" : "failed")")
    }

    func testWithoutAttachementTwo() {
        let result = false
        XCTAssert(result, "Test \(result ? "succeeded" : "failed")")
    }
}
