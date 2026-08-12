//
//  Run.swift
//  XCTestHTMLReport
//
//  Created by Titouan van Belle on 21.10.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation

struct Run: HTML {
    let file: PayloadProviding
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

    init?(
        run: ParsedRun,
        identifierPath: IdentifierPath,
        file: PayloadProviding,
        renderingMode: Summary.RenderingMode,
        downsizeImagesEnabled: Bool,
        downsizeScaleFactor: CGFloat
    ) {
        self.file = file
        runDestination = RunDestination(
            destination: run.destination,
            identifierPath: identifierPath
        )

        // TODO: (Pierre Felgines) 02/10/2019 Use only emittedOutput from logs objects
        // For now XCResultKit do not handle logs
        if let logReference = run.logReference {
            logContent = file.exportLogsContent(
                reference: logReference,
                renderingMode: renderingMode
            )
        } else {
            Logger.warning("Can't find log reference for run \(run.destination.displayName)")
            logContent = .none
        }

        let cpuCount = ProcessInfo.processInfo.processorCount
        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = cpuCount * 2

        let queue = DispatchQueue(label: "com.xchtmlreport.lock")

        // Keyed by source position: these are built concurrently, so the order
        // they land in is whatever order the operations happened to finish in.
        var summaries = [Int: TestSummary]()

        run.testables
            .enumerated()
            .forEach { index, testable in
                let operation = BlockOperation {
                    let summary = TestSummary(
                        testable: testable,
                        identifierPath: identifierPath.appending("target\(index)"),
                        file: file,
                        renderingMode: renderingMode,
                        downsizeImagesEnabled: downsizeImagesEnabled,
                        downsizeScaleFactor: downsizeScaleFactor
                    )
                    queue.sync {
                        summaries[index] = summary
                    }
                }
                operationQueue.addOperation(operation)
            }

        operationQueue.waitUntilAllOperationsAreFinished()

        // Sorting on `testName` alone is not a total order — a test plan with
        // several configurations yields several summaries for one target — and
        // `sorted(by:)` is not stable, so ties would resolve differently from
        // run to run. Break them on source position.
        testSummaries = summaries
            .sorted { ($0.value.testName, $0.key) < ($1.value.testName, $1.key) }
            .map(\.value)
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
