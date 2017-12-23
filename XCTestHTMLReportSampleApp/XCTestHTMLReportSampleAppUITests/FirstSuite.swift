//
//  FirstSuite.swift
//  XCTestHTMLReportSampleAppUITests
//
//  Created by Titouan van Belle on 23.07.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import XCTest

func randomBool() -> Bool {
    return arc4random_uniform(2) == 0
}

class FirstSuite: XCTestCase {
        
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

    func testDownloadAndAttachWebData() {
        let expectation = XCTestExpectation(description: "Download apple.com home page")
        let url = URL(string: "https://apple.com")!
        let dataTask = URLSession.shared.dataTask(with: url) { (data, urlResponse, error) in

            if let data = data {
                let html = XCTAttachment(data: data, uniformTypeIdentifier: "public.html")
                html.name = "HTML"
                html.lifetime = .keepAlways
                self.add(html)
            }


            expectation.fulfill()
        }

        dataTask.resume()
        wait(for: [expectation], timeout: 10.0)
    }

    func testOne() {
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

        let result = randomBool()
        XCTAssert(result, "Test \(result ? "succeeded" : "failed")")
    }

    func testTwo() {
        let result = randomBool()
        XCTAssert(result, "Test \(result ? "succeeded" : "failed")")
    }
}
