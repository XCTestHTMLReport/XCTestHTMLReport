//
//  ThirdSuite.swift
//  SampleAppUITests
//
//  Created by Fabien Lydoire on 12/06/18.
//  Copyright © 2018 Fabien Lydoire. All rights reserved.
//

import XCTest

private extension String {
    static let testSucceeded = "Test succeeded"
    static let testFailed = "Test failed"
}

class ThirdSuite: XCTestCase {
    override func setUp() {
        super.setUp()

        // Put setup code here. This method is called before the invocation of each test method in
        // the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = true
        // UI tests must launch the application that they test. Doing this in setup will make sure
        // it happens for each test method.
        XCUIApplication().launch()
    }

    func testOne() {
        XCTContext.runActivity(named: "test Activity - Success") { _ in
            XCTAssert(true, .testSucceeded)
        }
        XCTContext.runActivity(named: "test Activity - Failure") { _ in
            XCTAssert(false, .testFailed)
        }
        XCTContext.runActivity(named: "test Activity with sub-activities") { _ in
            XCTContext.runActivity(named: "test sub Activity 0 - Failure") { _ in
                XCTAssert(false, .testFailed)
            }
            XCTContext.runActivity(named: "test sub Activity 1 - Success") { _ in
                XCTAssert(true, .testSucceeded)
            }
        }
        XCTAssert(false, .testFailed)
        XCTAssert(true, .testSucceeded)
    }

    func testTwo() {
        XCTAssert(true, .testSucceeded)
    }
}
