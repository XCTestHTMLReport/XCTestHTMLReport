//
//  Run.swift
//  XCTestHTMLReport
//
//  Created by Titouan van Belle on 21.10.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation
import XCResultKit

struct Run: HTML {
    let file: ResultFile
    let runDestination: RunDestination
    let testSummaries: [TestSummary]
    let logContent: RenderingContent
    var status: Status {
        if let _ = testSummaries.first(where: { $0.status == .failure }) {
            return .failure
        }
        if let _ = testSummaries.first(where: { $0.status == .skipped }) {
            return .skipped
        }
        return .success
    }

    var allTests: [Test] {
        let tests = testSummaries.flatMap(\.tests)
        return tests.flatMap { test -> [Test] in
            let subTests = test.descendantSubTests
            if subTests.isEmpty {
                return [test]
            }
            return subTests
        }
    }

    var numberOfTests: Int {
        let a = allTests
        return a.count
    }

    var numberOfPassedTests: Int {
        allTests.filter { $0.status == .success }.count
    }

    var numberOfSkippedTests: Int {
        allTests.filter { $0.status == .skipped }.count
    }

    var numberOfFailedTests: Int {
        allTests.filter { $0.status == .failure }.count
    }

    var numberOfMixedTests: Int {
        allTests.filter { $0.status == .mixed }.count
    }

    init?(action: ActionRecord, file: ResultFile, renderingMode: Summary.RenderingMode, downsizeImagesEnabled: Bool) {
        self.file = file
        runDestination = RunDestination(record: action.runDestination)

        guard
            let testReference = action.actionResult.testsRef,
            let testPlanSummaries = file.getTestPlanRunSummaries(id: testReference.id)
        else {
            Logger.warning("Can't find test reference for action \(action.title ?? "")")
            return nil
        }

        // TODO: (Pierre Felgines) 02/10/2019 Use only emittedOutput from logs objects
        // For now XCResultKit do not handle logs
        if let logReference = action.actionResult.logRef {
            logContent = file.exportLogsContent(
                id: logReference.id,
                renderingMode: renderingMode
            )
        } else {
            Logger.warning("Can't find test reference for action \(action.title ?? "")")
            logContent = .none
        }
        testSummaries = testPlanSummaries.summaries
            .flatMap(\.testableSummaries)
            .map { TestSummary(summary: $0, file: file, renderingMode: renderingMode, downsizeImagesEnabled: downsizeImagesEnabled) }
    }

    private var logSource: String? {
        switch logContent {
        case let .url(url):
            return url.relativePath
        case let .data(data):
            return "data:text/plain;base64,\(data.base64EncodedString())"
        case .none:
            return nil
        }
    }

    // PRAGMA MARK: - HTML

    var htmlTemplate = HTMLTemplates.run

    var htmlPlaceholderValues: [String: String] {
        [
            "DEVICE_IDENTIFIER": runDestination.targetDevice.uniqueIdentifier,
            "LOG_SOURCE": logSource ?? "",
            "N_OF_TESTS": String(numberOfTests),
            "N_OF_PASSED_TESTS": String(numberOfPassedTests),
            "N_OF_SKIPPED_TESTS": String(numberOfSkippedTests),
            "N_OF_FAILED_TESTS": String(numberOfFailedTests),
            "N_OF_MIXED_TESTS": String(numberOfMixedTests),
            "TEST_SUMMARIES": testSummaries.map(\.html).joined(),
        ]
    }
}

extension Run: ContainingAttachment {
    var screenshotAttachments: [Attachment] {
        allAttachments.filter(\.isScreenshot)
    }

    var allAttachments: [Attachment] {
        allTests.map(\.allAttachments).reduce([], +)
    }
}
