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
    let runs: [Run]

    init(resultPaths: [String]) {
        var runs: [Run] = []
        for resultPath in resultPaths {
            Logger.step("Parsing \(resultPath)")
            let url = URL(fileURLWithPath: resultPath)
            let resultFile = ResultFile(url: url)
            guard let invocationRecord = resultFile.getInvocationRecord() else {
                Logger.warning("Can't find invocation record for : \(resultPath)")
                break
            }
            let resultRuns = invocationRecord.actions.compactMap {
                Run(action: $0, file: resultFile)
            }
            runs.append(contentsOf: resultRuns)
        }
        self.runs = runs
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
