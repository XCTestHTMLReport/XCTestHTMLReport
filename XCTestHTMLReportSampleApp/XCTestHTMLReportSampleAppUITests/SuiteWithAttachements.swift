//
//  AttachementsSuite.swift
//  XCUITestHTMLReportSampleAppUITests
//
//  Created by Titouan van Belle on 23.07.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import XCTest

class SuiteWithAttachements: XCTestCase {

    override func setUp() {
        super.setUp()

        continueAfterFailure = false

        XCUIApplication().launch()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testWithImageAttachement() {
        XCTContext.runActivity(named: "Image Attachment") { (activity) in
            let path = Bundle(for: SuiteWithAttachements.self).path(forResource: "iPhone", ofType: "png")
            let image = UIImage(contentsOfFile: path!)!
            let imageAttachement = XCTAttachment(image: image)
            imageAttachement.lifetime = .keepAlways
            activity.add(imageAttachement)
        }

        let result = true
        XCTAssert(result, "Test \(result ? "succeeded" : "failed")")
    }

    func testWithTextAttachement() {
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

        let result = true
        XCTAssert(result, "Test \(result ? "succeeded" : "failed")")
    }

    func testWithHTMLAttachement() {
        XCTContext.runActivity(named: "Text Attachment") { (activity) in
            let data = "<html><body><h1>HTML Data</h1></body></html>".data(using: .utf8)!
            let html = XCTAttachment(data: data, uniformTypeIdentifier: "public.html")
            html.name = "HTML"
            html.lifetime = .keepAlways
            activity.add(html)
        }

        let result = false
        XCTAssert(result, "Test \(result ? "succeeded" : "failed")")
    }
}

