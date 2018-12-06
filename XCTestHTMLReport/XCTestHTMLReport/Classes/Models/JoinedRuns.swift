//
//  JoinedRuns.swift
//  XCTestHTMLReport
//
//  Created by Alistair Leszkiewicz on 11/30/18.
//  Copyright © 2018 Tito. All rights reserved.
//

import Foundation

// Represents a series of test runs joined together into a single
// success / failure run
struct JoinedRuns : HTML
{
    let runs: [Run]
    
    init(runs: [Run]) {
        self.runs = runs
    }

    var htmlTemplate = HTMLTemplates.run

    var numberOfTests : Int {
        return runs.map { $0.numberOfTests }.sum()
    }
    
    var numberOfPassedTests : Int {
        return runs.map { $0.numberOfPassedTests }.sum()
    }
    
    var numberOfFailedTests : Int {
        return runs.map { $0.numberOfFailedTests }.sum()
    }
    
    var testSummaries: [TestSummary] {
        return runs.flatMap { $0.testSummaries }
    }
    
    var htmlPlaceholderValues: [String: String] {
        return [
            "DEVICE_IDENTIFIER": "ALL",
            "N_OF_TESTS": String(numberOfTests),
            "N_OF_PASSED_TESTS": String(numberOfPassedTests),
            "N_OF_FAILED_TESTS": String(numberOfFailedTests),
            "TEST_SUMMARIES": testSummaries.map { $0.prefixUUIDForJoinedRunWithChildren() }.map { $0.html }.joined()
        ]
    }
}


private extension Array where Element == Int {
    
    func sum() -> Int {
        return reduce(0, +)
    }
    
}

/// To keep these UUID's unique within the HTML document
/// they are all pre-pended with the constant string 'ALL'
fileprivate protocol JoinedTestSummaryDisplayProtocol {
    var uuid: String { get set }
    func prefixUUIDForJoinedRun() -> Self
    func prefixUUIDForJoinedRunWithChildren() -> Self
}

fileprivate extension JoinedTestSummaryDisplayProtocol {
    
    func prefixUUIDForJoinedRun() -> Self {
        var copy = self
        copy.uuid = "ALL-" + copy.uuid
        return copy
    }
    
    func prefixUUIDForJoinedRunWithChildren() -> Self {
        return prefixUUIDForJoinedRun()
    }
}

extension TestSummary: JoinedTestSummaryDisplayProtocol {
    
    func prefixUUIDForJoinedRunWithChildren() -> TestSummary {
        var copy = self.prefixUUIDForJoinedRun()
        copy.tests = copy.tests.map { $0.prefixUUIDForJoinedRunWithChildren() }
        return copy
    }
    
}

extension Test: JoinedTestSummaryDisplayProtocol {
    
    func prefixUUIDForJoinedRunWithChildren() -> Test {
        var copy = self.prefixUUIDForJoinedRun()
        copy.subTests = copy.subTests?.map { $0.prefixUUIDForJoinedRunWithChildren() }
        copy.activities = copy.activities?.map { $0.prefixUUIDForJoinedRunWithChildren() }
        return copy
    }
    
}
extension Activity: JoinedTestSummaryDisplayProtocol {
    
    func prefixUUIDForJoinedRunWithChildren() -> Activity {
        var copy = self.prefixUUIDForJoinedRun()
        copy.subActivities = copy.subActivities?.map { $0.prefixUUIDForJoinedRunWithChildren() }
        return copy
    }

    
}
