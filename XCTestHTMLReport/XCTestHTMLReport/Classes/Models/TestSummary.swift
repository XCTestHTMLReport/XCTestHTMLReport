//
//  Summary.swift
//  XCTestHTMLReport
//
//  Created by Titouan van Belle on 21.07.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation

struct TestSummary: HTML
{
    var uuid: String
    var testName: String
    var tests: [Test]
    var status: Status {
        let currentTests = tests
        var status: Status = .unknown

        if currentTests.count == 0 {
            return .success
        }
        
        var currentSubtests: [Test] = []
        for test in currentTests {
            currentSubtests += test.rootSubtests()
        }

        status = currentSubtests.reduce(.unknown, { (accumulator: Status, test: Test) -> Status in
            if accumulator == .unknown {
                return test.status
            }

            if test.status == .failure {
                return .failure
            }

            if test.status == .success {
                return accumulator == .failure ? .failure : .success
            }

            return .unknown
        })

        return status
    }

    init(screenshotsPath: String, dict: [String : Any])
    {
        Logger.substep("Parsing TestSummary")
        
        uuid = NSUUID().uuidString
        testName = dict["TestName"] as! String
        let rawTests = dict["Tests"] as! [[String: Any]]
        tests = rawTests.map { Test(screenshotsPath: screenshotsPath, dict: $0) }
    }

    // PRAGMA MARK: - HTML

    var htmlTemplate = HTMLTemplates.testSummary

    var htmlPlaceholderValues: [String: String] {
        return [
            "UUID": uuid,
            "TESTS": tests.reduce("", { (accumulator: String, test: Test) -> String in
                return accumulator + test.html
            })
        ]
    }
}

extension Test {
    func rootSubtests() -> [Test] {
        guard let subTests = self.subTests, subTests.isEmpty == false else {
            return [self]
        }
        var testsToReturn: [Test] = []
        for test in subTests {
            testsToReturn += test.rootSubtests()
        }
        return testsToReturn
    }
}
