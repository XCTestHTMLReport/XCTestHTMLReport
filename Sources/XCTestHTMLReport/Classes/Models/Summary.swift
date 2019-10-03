//
//  Summary.swift
//  XCTestHTMLReport
//
//  Created by Titouan van Belle on 21.07.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation
import XCResultKit

struct Summary
{
    private let filename = "action_TestSummaries.plist"

    var runs = [Run]()

    init(resultPaths: [String]) {
        for resultPath in resultPaths {
            Logger.step("Parsing \(resultPath)")

            guard let url = URL(string: resultPath) else {
                Logger.error("Can't create url for : \(resultPath)")
                exit(EXIT_FAILURE)
            }
            let resultFile = XCResultFile(url: url)
            guard let invocationRecord = resultFile.getInvocationRecord() else {
                Logger.error("Can't find invocation record for : \(resultPath)")
                exit(EXIT_FAILURE)
            }
            let runs = invocationRecord.actions.compactMap {
                Run(action: $0, file: resultFile)
            }
            self.runs.append(contentsOf: runs)
        }
    }
}

extension Summary: HTML
{
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

extension Summary: JUnitRepresentable
{
    var junit: JUnitReport {
        return JUnitReport(summary: self)
    }
}
