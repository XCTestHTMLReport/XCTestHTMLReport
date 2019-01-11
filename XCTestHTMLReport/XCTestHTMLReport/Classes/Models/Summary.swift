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
    private let validIconUrl = "https://raw.githubusercontent.com/applidium/XCTestHTMLReport/develop_ad/XCTestHTMLReport/XCTestHTMLReport/Resources/valid.png"
    private let invalidIconUrl = "https://raw.githubusercontent.com/applidium/XCTestHTMLReport/develop_ad/XCTestHTMLReport/XCTestHTMLReport/Resources/invalid.png"

    var runs = [Run]()
    var totalNumberOfTests: Int {
        return runs.reduce(0) { $0 + $1.numberOfTests }
    }
    var totalNumberOfPassedTests: Int {
        return runs.reduce(0) { $0 + $1.numberOfPassedTests }
    }
    var totalNumberOfFailedTests: Int {
        return runs.reduce(0) { $0 + $1.numberOfFailedTests }
    }

    init(roots: [String])
    {
        let indexHTMLRoot = roots[0]
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
                let run = Run(root: root, path: path, indexHTMLRoot: indexHTMLRoot)
                runs.append(run)
            }
        }
    }

    //MARK: - Private

    private func isSummaryValid() -> Bool {
        return runs.reduce(true) { (accumulator: Bool, run: Run) -> Bool in
            return accumulator && run.status == .success
        }
    }
}

extension Summary: HTML
{
    var htmlTemplate: String {
        return HTMLTemplates.index
    }

    var htmlPlaceholderValues: [String: String] {
        let isSummaryValid = self.isSummaryValid()
        return [
            "OG_IMAGE": isSummaryValid ? validIconUrl : invalidIconUrl,
            "OG_DESCRIPTION": "Total test count : \(totalNumberOfTests). \(totalNumberOfPassedTests) passed, \(totalNumberOfFailedTests) failed.",
            "DEVICES": runs.map { $0.runDestination.html }.joined(),
            "RESULT_CLASS": isSummaryValid ? "success" : "failure",
            "RUNS": runs.map { $0.html }.joined()
        ]
    }
}

extension Summary: JUnitRepresentable
{
    var junit: JUnitReport {
        return JUnitReport(summary: self)
    }
}
