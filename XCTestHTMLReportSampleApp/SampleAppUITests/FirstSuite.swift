//
//  FirstSuite.swift
//  SampleAppUITests
//
//  Created by Titouan van Belle on 23.07.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import XCTest

class FirstSuite: XCTestCase {
    override func setUp() {
        super.setUp()

        // Put setup code here. This method is called before the invocation of each test method in
        // the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        // UI tests must launch the application that they test. Doing this in setup will make sure
        // it happens for each test method.
        XCUIApplication().launch()

        // In UI tests it’s important to set the initial state - such as interface orientation -
        // required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in
        // the class.
        super.tearDown()
    }

    func testAttachHtmlData() {
        // Previously fetched https://apple.com, which made fixture generation
        // network-dependent. The attachment only needs to be public.html data.
        let markup = """
        <!doctype html>
        <html><head><title>Sample</title></head>
        <body><p>Sample attachment body</p></body></html>
        """
        let html = XCTAttachment(
            data: Data(markup.utf8),
            uniformTypeIdentifier: "public.html"
        )
        html.name = "HTML"
        html.lifetime = .keepAlways
        add(html)
    }

    func testOne() {
        XCTContext.runActivity(named: "Text Attachment") { activity in
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
        XCTAssert(true, "Test succeeded")
    }

    func testTwo() {
        XCTAssert(false, "Test failed")
    }

    func testWithSpecialChars() {
        let specialChars = "DoubleQuote\"SingleQuote'LessThan<GreaterThan>Ampersand&"
        XCTContext.runActivity(named: "Activity with \(specialChars)") { activity in
            let logsAttachement = XCTAttachment(string: "This is a log")
            logsAttachement.lifetime = .keepAlways
            logsAttachement.name = "FileName with \(specialChars)"
            activity.add(logsAttachement)
            XCTAssert(false, "Test with \(specialChars) failed on purpose")
        }
    }
}
