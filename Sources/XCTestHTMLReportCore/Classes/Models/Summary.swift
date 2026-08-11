//
//  Summary.swift
//  XCTestHTMLReport
//
//  Created by Titouan van Belle on 21.07.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation
import XCResultKit

public struct Summary {
    let runs: [Run]
    let resultFiles: [ResultFile]
    private let faultCollector: FaultCollector

    public enum RenderingMode {
        case inline
        case linking
    }

    /// All degradation encountered while building this report.
    public var faults: [Fault] {
        faultCollector.faults
    }

    public init(
        resultPaths: [String],
        renderingMode: RenderingMode,
        downsizeImagesEnabled: Bool,
        downsizeScaleFactor: CGFloat,
        faultCollector: FaultCollector = FaultCollector()
    ) {
        var runs: [Run] = []
        var resultFiles: [ResultFile] = []
        self.faultCollector = faultCollector

        for (resultIndex, resultPath) in resultPaths.enumerated() {
            Logger.step("Parsing \(resultPath)")
            let url = URL(fileURLWithPath: resultPath)
            let resultFile = ResultFile(url: url, faultCollector: faultCollector)
            resultFiles.append(resultFile)
            guard let invocationRecord = resultFile.getInvocationRecord() else {
                Logger.warning("Can't find invocation record for : \(resultPath)")
                faultCollector.record(.missingInvocationRecord, resultPath)
                // Previously `break`, which silently abandoned every remaining
                // bundle when multiple were passed.
                continue
            }
            // Identifiers are derived from the bundle's position in the
            // argument list rather than from its path, so moving a bundle
            // between directories still renders the same report. See
            // `IdentifierPath`.
            let resultRuns = invocationRecord.actions.enumerated()
                .compactMap { actionIndex, action in
                    Run(
                        action: action,
                        identifierPath: IdentifierPath.root
                            .appending("bundle\(resultIndex)")
                            .appending("action\(actionIndex)"),
                        file: resultFile,
                        renderingMode: renderingMode,
                        downsizeImagesEnabled: downsizeImagesEnabled,
                        downsizeScaleFactor: downsizeScaleFactor
                    )
                }
            runs.append(contentsOf: resultRuns)
        }
        self.runs = runs
        self.resultFiles = resultFiles
    }

    /// Generate HTML report
    /// - Returns: Generated HTML report string
    public func generatedHtmlReport() -> String {
        html
    }

    /// Generate JUnit report
    /// - Returns: Generated JUnit XML report string
    public func generatedJunitReport(includeRunDestinationInfo: Bool) -> String {
        junit(includeRunDestinationInfo: includeRunDestinationInfo).xmlString
    }

    /// Delete all unattached files in runs
    public func deleteUnattachedFiles() {
        Logger.substep("Deleting unattached files..")
        var deletedFilesCount = 0
        deletedFilesCount = removeUnattachedFiles(runs: runs)
        Logger.substep("Deleted \(deletedFilesCount) unattached files")
    }

    public func generatedJsonReport() -> String {
        let jsonStrings: [String] = resultFiles.compactMap { resultFile in
            guard let jsonData = resultFile.exportJson() else {
                return nil
            }
            return String(data: jsonData, encoding: .utf8)
        }

        // TODO: The result files may be encoded directly as an array instead of concatenating raw output
        return "[\(jsonStrings.joined(separator: ","))]"
    }

    /// Check post-conditions on the assembled model and record any degradation.
    ///
    /// Call-site checks catch failures XCResultKit surfaces as `nil`. They do
    /// not catch failures in *nested* decoding, where a parent object still
    /// decodes but a child field comes back empty. The observable symptom is an
    /// attachment that resolved to no content, so check for that directly.
    ///
    /// Idempotent across sequential calls: repeated calls do not duplicate
    /// faults. Dedup keys on `Attachment.faultDescription`, which assumes
    /// `allAttachments` is stable for this value's lifetime — it is, since
    /// `runs` is a `let`. Not safe to call concurrently with itself: the
    /// read of `faults` and the subsequent `record` are separately
    /// synchronized, not atomic as a unit.
    public func validate() {
        let alreadyFlagged = Set(
            faultCollector.faults
                .filter { $0.kind == .unresolvedAttachment }
                .map(\.detail)
        )

        for attachment in allAttachments {
            guard case .none = attachment.content else {
                continue
            }
            let detail = attachment.faultDescription
            guard !alreadyFlagged.contains(detail) else {
                continue
            }
            faultCollector.record(.unresolvedAttachment, detail)
        }
    }
}

extension Summary: HTML {
    var htmlTemplate: String {
        HTMLTemplates.index
    }

    var htmlPlaceholderValues: [String: String] {
        let resultClass: String
        if runs.contains(where: { $0.status == .failure }) {
            resultClass = "failure"
        } else if runs.contains(where: { $0.status == .success }) {
            resultClass = "success"
        } else {
            resultClass = "skip"
        }
        return [
            "DEVICES": runs.map(\.runDestination.html).joined(),
            "RESULT_CLASS": resultClass,
            "RUNS": runs.map(\.html).joined(),
        ]
    }
}

extension Summary: JUnitRepresentable {
    func junit(includeRunDestinationInfo: Bool) -> JUnitReport {
        JUnitReport(summary: self, includeRunDestinationInfo: includeRunDestinationInfo)
    }
}

extension Summary: ContainingAttachment {
    var allAttachments: [Attachment] {
        runs.map(\.allAttachments).reduce([], +)
    }
}
