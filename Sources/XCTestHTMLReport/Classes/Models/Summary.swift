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

    enum RenderingMode {
        case inline
        case linking
    }

    init(resultPaths: [String], renderingMode: RenderingMode) {
        var runs: [Run] = []
        for resultPath in resultPaths {
            Logger.step("Parsing \(resultPath)")
            let url = URL(fileURLWithPath: resultPath)
            let resultFile = ResultFile(url: url)
            guard let invocationRecord = resultFile.getInvocationRecord() else {
                Logger.warning("Can't find invocation record for : \(resultPath)")
                break
            }
            let resultRuns = invocationRecord.actions.concurrentCompactMap {
                Run(action: $0, file: resultFile, renderingMode: renderingMode)
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
        let resultClass: String
        if runs.first(where: { $0.status == .failure }) != nil {
            resultClass = "failure"
        } else if runs.first(where: { $0.status == .success }) != nil {
            resultClass = "success"
        } else {
            resultClass = "skip"
        }
        return [
            "DEVICES": runs.map { $0.runDestination.html }.joined(),
            "RESULT_CLASS": resultClass,
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
