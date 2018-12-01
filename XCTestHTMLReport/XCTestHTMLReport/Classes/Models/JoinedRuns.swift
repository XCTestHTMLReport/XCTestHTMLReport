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
            "TEST_SUMMARIES": testSummaries.map { $0.html }.joined()
        ]
    }
}


private extension Array where Element == Int {
    
    func sum() -> Int {
        return reduce(0, +)
    }
    
}
