//
//  Summary.swift
//  XCTestHTMLReport
//
//  Created by Titouan van Belle on 21.07.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation
import XCResultKit

public struct Summary
{
    let runs: [Run]

    public enum RenderingMode {
        case inline
        case linking
    }

    public init(resultPaths: [String], renderingMode: RenderingMode) {
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
                Run(action: $0, file: resultFile, renderingMode: renderingMode)
            }
            runs.append(contentsOf: resultRuns)
        }
        self.runs = runs
    }

    /// Reduce size of all images in attachments
    public func reduceImageSizes() {
        Logger.substep("Resizing images..")
        var resizedCount = 0
        for run in runs {
            for screenshotAttachment in run.screenshotAttachments {
                let resized = resizeImage(atPath: run.file.url.path + "/../" + (screenshotAttachment.source ?? ""))
                if resized {
                    resizedCount += 1
                }
            }
        }
        Logger.substep("Finished resizing \(resizedCount) images")
    }

    /// Generate HTML report
    /// - Returns: Generated HTML report string
    public func generatedHtmlReport() -> String {
        return html
    }

    /// Generate JUnit report
    /// - Returns: Generated JUnit XML report string
    public func generatedJunitReport() -> String {
        return junit.xmlString
    }

    /// Delete all unattached files in runs
    public func deleteUnattachedFiles() {
        Logger.substep("Deleting unattached files..")
        var deletedFilesCount = 0
        deletedFilesCount = removeUnattachedFiles(runs: runs)
        Logger.substep("Deleted \(deletedFilesCount) unattached files")
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
