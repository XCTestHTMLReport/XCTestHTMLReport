//
//  ThirdSuite.swift
//  XCTestHTMLReportSampleAppUITests
//
//  Created by Fabien Lydoire on 12/06/18.
//  Copyright © 2018 Fabien Lydoire. All rights reserved.
//

import XCTest

class ThirdSuite: XCTestCase {

	override func setUp() {
		super.setUp()

		// Put setup code here. This method is called before the invocation of each test method in the class.

		// In UI tests it is usually best to stop immediately when a failure occurs.
		continueAfterFailure = true
		// UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
		XCUIApplication().launch()
	}

	func testOne() {
		XCTContext.runActivity(named: "test Activity - Success") { _ in
			XCTAssert(true, "Test succeeded")
		}
		XCTContext.runActivity(named: "test Activity - Failure") { _ in
			XCTAssert(false, "Test failed")
		}
		XCTContext.runActivity(named: "test Activity with sub-activities") { _ in
			XCTContext.runActivity(named: "test sub Activity 0 - Failure") { _ in
				XCTAssert(false, "Test failed")
			}
			XCTContext.runActivity(named: "test sub Activity 1 - Success") { _ in
				XCTAssert(true, "Test succeeded")
			}
		}
		XCTAssert(false, "Test failed")
		XCTAssert(true, "Test succeeded")
	}

	func testTwo() {
		let result = randomBool()
		XCTAssert(result, "Test \(result ? "succeeded" : "failed")")
	}
}
