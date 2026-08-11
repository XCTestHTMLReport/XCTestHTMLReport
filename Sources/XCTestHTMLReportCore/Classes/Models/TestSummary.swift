//
//  TestSummary.swift
//  XCTestHTMLReport
//
//  Created by Titouan van Belle on 21.07.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation
import XCResultKit

struct TestSummary: HTML {
    let uuid: String
    let testName: String
    let tests: [TestGroup]
    var status: Status {
        let currentTests = tests
        var status: Status = .unknown

        if currentTests.count == 0 {
            return .success
        }

        // TODO: Include mixed status
        status = currentTests.reduce(.unknown) { (accumulator: Status, test: TestGroup) -> Status in
            if accumulator == .unknown {
                return test.status
            }

            if test.status == .failure {
                return .failure
            }

            if test.status == .success {
                return accumulator == .failure ? .failure : .success
            }

            return .unknown
        }

        return status
    }

    init(
        summary: ActionTestableSummary,
        identifierPath: IdentifierPath,
        file: ResultFile,
        renderingMode: Summary.RenderingMode,
        downsizeImagesEnabled: Bool,
        downsizeScaleFactor: CGFloat
    ) {
        let targetName = summary.targetName ?? ""
        let path = identifierPath.appending(targetName)
        uuid = path.identifier
        testName = targetName
        // TODO: Reduce this with iterations & accum with hashmap
        tests = summary.tests.enumerated().map { index, group in
            TestGroup(
                group: group,
                identifierPath: path.appending("group\(index)"),
                resultFile: file,
                renderingMode: renderingMode,
                downsizeImagesEnabled: downsizeImagesEnabled,
                downsizeScaleFactor: downsizeScaleFactor
            )
        }
    }

    // PRAGMA MARK: - HTML

    var htmlTemplate = HTMLTemplates.testSummary

    var htmlPlaceholderValues: [String: String] {
        [
            "UUID": uuid,
            "TESTS": tests.accumulateHtml(),
        ]
    }
}

extension TestSummary: ContainingAttachment {
    var allAttachments: [Attachment] {
        tests.map(\.allAttachments).reduce([], +)
    }
}
