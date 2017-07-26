//
//  SecondSuite.swift
//  XCUITestHTMLReportSampleAppUITests
//
//  Created by Titouan van Belle on 23.07.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import XCTest

class SecondSuite: XCTestCase {

    override func setUp() {
        super.setUp()

        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
        XCUIApplication().launch()

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testSecondSuiteButtonExists() {
        XCTContext.runActivity(named: "Text Attachment") { (activity) in
            let logs = """
                This is a log
                This is a log
                This is a log
                This is a log
                This is a log
                This is a log
            """
            let logsAttachement = XCTAttachment(string: logs)
            logsAttachement.lifetime = .keepAlways
            activity.add(logsAttachement)
        }

        XCTContext.runActivity(named: "Image Attachment") { (activity) in
            let path = Bundle(for: SecondSuite.self).path(forResource: "iPhone", ofType: "png")
            let image = UIImage(contentsOfFile: path!)!
            let attachment = XCTAttachment(image: image)
            attachment.lifetime = .keepAlways
            activity.add(attachment)
        }

        XCTAssert(XCUIApplication().buttons["Button"].exists, "Button does not exist")
    }

    func testSecondSuiteButtonDoesNotExist() {
        XCTAssert(!XCUIApplication().buttons["Button"].exists, "Button exists")
    }

}

