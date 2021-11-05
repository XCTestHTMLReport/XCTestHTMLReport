//
//  Summary.swift
//  XCTestHTMLReport
//
//  Created by Titouan van Belle on 21.07.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation
import XCResultKit

struct TestSummary: HTML
{
    let uuid: String
    let testName: String
    let tests: [Test]
    var status: Status {
        let currentTests = tests
        var status: Status = .unknown
        
        var currentSubtests: [Test] = []
        for test in currentTests {
            currentSubtests += test.allTestSummaries()
        }
        
        if currentSubtests.count == 0 {
            return .success
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
    
    var isEmpty: Bool {
        return tests.isEmpty
    }

    init?(summary: ActionTestableSummary, file: ResultFile, renderingArgs: RenderingArguments) {
        self.uuid = UUID().uuidString
        self.testName = summary.targetName ?? ""
        self.tests = summary.tests.compactMap { Test(group: $0, file: file, renderingArgs: renderingArgs) }
        if isEmpty {
            return nil
        }
    }

    // PRAGMA MARK: - HTML

    var htmlTemplate = HTMLTemplates.testSummary

    var htmlPlaceholderValues: [String: String] {
        return [
            "UUID": uuid,
            "TESTS": tests.accumulateHTMLAsString
        ]
    }
}

extension Test {
    func allTestSummaries() -> [Test] {
        if self.objectClass == .testSummary {
            return [self]
        }
        return subTests.flatMap { $0.allTestSummaries() }
    }
}
