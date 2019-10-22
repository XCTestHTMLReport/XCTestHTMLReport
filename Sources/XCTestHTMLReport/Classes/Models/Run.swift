//
//  Run.swift
//  XCTestHTMLReport
//
//  Created by Titouan van Belle on 21.10.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation
import XCResultKit

struct Run: HTML
{
    let runDestination: RunDestination
    let testSummaries: [TestSummary]
    let logPath: String
    var status: Status {
       return testSummaries.reduce(true, { (accumulator: Bool, summary: TestSummary) -> Bool in
            return accumulator && summary.status == .success
        }) ? .success : .failure
    }
    var allTests: [Test] {
        let tests = testSummaries.flatMap { $0.tests }
        return tests.flatMap { test -> [Test] in
            return test.allSubTests.isEmpty
                ? [test]
                : test.allSubTests
        }
    }
    var numberOfTests : Int {
        let a = allTests
        return a.count
    }
    var numberOfPassedTests : Int {
        return allTests.filter { $0.status == .success }.count
    }
    var numberOfFailedTests : Int {
        return allTests.filter { $0.status == .failure }.count
    }

    init?(action: ActionRecord, file: ResultFile) {
        self.runDestination = RunDestination(record: action.runDestination)

        guard
            let testReference = action.actionResult.testsRef,
            let testPlanSummaries = file.getTestPlanRunSummaries(id: testReference.id) else {
                Logger.warning("Can't find test reference for action \(action.title ?? "")")
                return nil
        }

        // TODO: (Pierre Felgines) 02/10/2019 Use only emittedOutput from logs objects
        // For now XCResultKit do not handle logs
        if let logReference = action.actionResult.logRef,
            let url = file.exportLogs(id: logReference.id) {
            self.logPath = url.relativePath
        } else {
            Logger.warning("Can't find test reference for action \(action.title ?? "")")
            self.logPath = ""
        }
        self.testSummaries = testPlanSummaries.summaries
            .flatMap { $0.testableSummaries }
            .map { TestSummary(summary: $0, file: file) }
    }

    // PRAGMA MARK: - HTML

    var htmlTemplate = HTMLTemplates.run

    var htmlPlaceholderValues: [String: String] {
        return [
            "DEVICE_IDENTIFIER": runDestination.targetDevice.uniqueIdentifier,
            "LOG_PATH": logPath,
            "N_OF_TESTS": String(numberOfTests),
            "N_OF_PASSED_TESTS": String(numberOfPassedTests),
            "N_OF_FAILED_TESTS": String(numberOfFailedTests),
            "TEST_SUMMARIES": testSummaries.map { $0.html }.joined()
        ]
    }

}
