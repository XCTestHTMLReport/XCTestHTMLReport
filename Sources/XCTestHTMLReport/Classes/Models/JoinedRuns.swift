//
//  JoinedRuns.swift
//  XCTestHTMLReport
//
//  Created by Alistair Leszkiewicz on 11/30/18.
//  Copyright © 2018 Tito. All rights reserved.
//

import Foundation
import XCResultKit

// Represents a series of test runs joined together into a single
// success / failure run
struct JoinedRuns : HTML
{
    let testGroupCollections: [TestGroupCollection]

    var numberOfTests : Int {
        return testGroupCollections.reduce(0, { $0 + $1.testGroups.count })
    }

    var numberOfPassedTests : Int {
        return allTestGroups.filter { $0.status == .success }.count
    }

    var numberOfSkippedTests : Int {
        return allTestGroups.filter { $0.status == .skipped }.count
    }

    var numberOfFailedTests : Int {
        return allTestGroups.filter { $0.status == .failure }.count
    }

    var allTestGroups: [TestGroup] {
        return testGroupCollections.flatMap { $0.testGroups }
    }
    
    init(runs: [Run]) {
        testGroupCollections = runs
            .flatMap { $0.testSummaries }
            .flatMap { $0.tests }
            .flatMap { $0.allSubTests }
            .reduce(into: [String: [String: [Test]]]()) { acc, test in
                if let cases = acc[test.summaryGroup.identifier] {
                    if let tests = cases[test.identifier] {
                        acc[test.summaryGroup.identifier]![test.identifier] = tests + [test]
                    } else {
                        acc[test.summaryGroup.identifier]![test.identifier] = [test]
                    }
                } else {
                    acc[test.summaryGroup.identifier] = [test.identifier: [test]]
                }
            }
            .map { identifier, cases -> TestGroupCollection in
                let groups = cases
                    .values
                    .map { tests -> TestGroup in
                        let test = tests.first { $0.status == .success } ?? tests.last!
                        let isSuccess = test.status == .success

                        return TestGroup(
                            group: test.summaryGroup,
                            tests: tests
                                .enumerated()
                                .map { offset, element -> Test in
                                    if isSuccess || element.status == .success || offset < tests.count - 1 {
                                        return element.removingScreenshotFlow()
                                            .regeneratingUUID()
                                    }

                                    return element
                                        .regeneratingUUID()
                                }
                        )
                    }

                return TestGroupCollection(
                    name: identifier,
                    testGroups: groups
                )
            }
    }

    var htmlTemplate = HTMLTemplates.run
    
    var htmlPlaceholderValues: [String: String] {
        return [
            "DEVICE_IDENTIFIER": "ALL",
            "N_OF_TESTS": String(numberOfTests),
            "N_OF_PASSED_TESTS": String(numberOfPassedTests),
            "N_OF_FAILED_TESTS": String(numberOfFailedTests),
            "N_OF_SKIPPED_TESTS": String(numberOfSkippedTests),
            "TEST_SUMMARIES": testGroupCollections.accumulateHTMLAsString
        ]
    }
}
