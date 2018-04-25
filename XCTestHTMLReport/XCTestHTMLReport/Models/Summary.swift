//
//  Summary.swift
//  XCTestHTMLReport
//
//  Created by Titouan van Belle on 21.07.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation

struct Summary
{
    private let filename = "action_TestSummaries.plist"

    var runs = [Run]()

    init(roots: [String])
    {

        for root in roots {
            Logger.step("Parsing Test Summaries")
            let enumerator = FileManager.default.enumerator(atPath: root)

            guard enumerator != nil else {
                Logger.error("Failed to create enumerator for path \(root)")
                exit(EXIT_FAILURE)
            }

            let paths = enumerator?.allObjects as! [String]

            Logger.substep("Searching for \(filename) in \(root)")
            let plistPath = paths.filter { $0.contains("action_TestSummaries.plist") }

            if plistPath.count == 0 {
                Logger.error("Failed to find action_TestSummaries.plist in \(root)")
                exit(EXIT_FAILURE)
            }

            for path in plistPath {
                let run = Run(root: root, path: path)
                runs.append(run)
            }
        }
    }
}

extension Summary: HTML {
    var htmlTemplate: String {
        return HTMLTemplates.index
    }

    var htmlPlaceholderValues: [String: String] {
        return [
            "DEVICES": runs.map { $0.runDestination.html }.joined(),
            "RESULT_CLASS": runs.reduce(true, { (accumulator: Bool, run: Run) -> Bool in
                return accumulator && run.status == .success
            }) ? "success" : "failure",
            "RUNS": runs.map { $0.html }.joined()
        ]
    }
}

extension Summary: JUnitRepresentable {
    var junit: JUnit {
        return JUnit(summary: self)
    }
}

extension JUnit {
    init(summary: Summary) {
        name = "All"
        suites = summary.runs.map { JUnit.TestSuite(run: $0) }
    }
}

extension JUnit.TestCase {
    init(test: Test) {
        let components = test.identifier.components(separatedBy: "/")
        time = test.duration
        name = components.last ?? ""
        classname = components.first ?? ""
        switch test.status {
        case .failure:
            state = .failed
        case .success:
            state = .passed
        case .unknown:
            state = .unknown
        }
    }
}

extension JUnit.TestSuite {
    init(run: Run) {
        name = (run.testSummaries.first?.testName ?? "") + " - " + run.runDestination.name + " - " + run.runDestination.targetDevice.osVersion
        tests = run.numberOfTests
        cases = run.allTests.map { JUnit.TestCase(test: $0) }
    }
}
