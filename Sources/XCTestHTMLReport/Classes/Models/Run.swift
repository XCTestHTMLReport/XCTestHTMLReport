//
//  Run.swift
//  XCTestHTMLReport
//
//  Created by Titouan van Belle on 21.10.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation
import XCResultKit

struct Run: HTML
{
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
        let tests = testSummaries.flatMap { $0.tests }
        return tests.flatMap { test -> [Test] in
            return test.allSubTests.isEmpty
                ? [test]
                : test.allSubTests
        }
    }
    var numberOfTests : Int {
        let a = allTests
        return a.count
    }
    var numberOfPassedTests : Int {
        return allTests.filter { $0.status == .success }.count
    }
    var numberOfSkippedTests : Int {
        return allTests.filter { $0.status == .skipped }.count
    }
    var numberOfFailedTests : Int {
        return allTests.filter { $0.status == .failure }.count
    }

    init?(action: ActionRecord, file: ResultFile, renderingMode: Summary.RenderingMode) {
        self.file = file
        self.runDestination = RunDestination(record: action.runDestination)

        guard
            let testReference = action.actionResult.testsRef,
            let testPlanSummaries = file.getTestPlanRunSummaries(id: testReference.id) else {
                Logger.warning("Can't find test reference for action \(action.title ?? "")")
                return nil
        }

        // TODO: (Pierre Felgines) 02/10/2019 Use only emittedOutput from logs objects
        // For now XCResultKit do not handle logs
        if let logReference = action.actionResult.logRef {
            self.logContent = file.exportLogsContent(
                id: logReference.id,
                renderingMode: renderingMode
            )
        } else {
            Logger.warning("Can't find test reference for action \(action.title ?? "")")
            self.logContent = .none
        }
        self.testSummaries = testPlanSummaries.summaries
            .flatMap { $0.testableSummaries }
            .map { TestSummary(summary: $0, file: file, renderingMode: renderingMode) }
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
        return [
            "DEVICE_IDENTIFIER": runDestination.targetDevice.uniqueIdentifier,
            "LOG_SOURCE": logSource ?? "",
            "N_OF_TESTS": String(numberOfTests),
            "N_OF_PASSED_TESTS": String(numberOfPassedTests),
            "N_OF_SKIPPED_TESTS": String(numberOfSkippedTests),
            "N_OF_FAILED_TESTS": String(numberOfFailedTests),
            "TEST_SUMMARIES": testSummaries.map { $0.html }.joined()
        ]
    }

}
