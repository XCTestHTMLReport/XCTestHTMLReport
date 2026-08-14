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
    /// The reference this run's log content was resolved from, kept so that a
    /// failure to resolve it can be reported against something identifiable —
    /// the same reason `Attachment` keeps `payloadId`.
    let logReference: String?
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

        logReference = run.logReference

        // TODO: (Pierre Felgines) 02/10/2019 Use only emittedOutput from logs objects
        // For now XCResultKit do not handle logs
        if let logReference = run.logReference {
            logContent = file.exportLogsContent(
                reference: logReference,
                renderingMode: renderingMode,
                // Named from the run's identifier path, not from `reference`:
                // the reference is backend-internal (a CAS id on legacy, a
                // `--type` selector on modern), so a file named after it can
                // never agree across backends. The path digest is the same
                // scheme every element id already uses (#430), identical on
                // both backends, and unique per run — a multi-action bundle
                // gets one log file per action instead of a shared name that
                // would leave last-writer-wins. No fixture exercises multiple
                // actions, so that property is asserted here rather than in a
                // test.
                fileName: "\(identifierPath.identifier).log"
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

    /// Whether this run represents a failure to resolve its log.
    ///
    /// A run with no log reference has nothing to resolve: its log content is
    /// `.none` by construction, which is not degradation — the same rule
    /// `Attachment.failedToResolve` applies to an attachment that never had a
    /// payload (#387). Only a reference that existed and produced no content
    /// is a genuine failure (#386).
    ///
    /// This is a post-condition, not a substitute for the call-site checks in
    /// the payload providers: those name the *cause* (`.logExportFailed`),
    /// this catches the *symptom* whatever the cause, including the failures
    /// a call site cannot see. The motivating one is legacy: XCResultKit
    /// decodes `actionResult.logRef` tolerantly, so a log reference that
    /// exists in the bundle but fails to decode arrives here as `nil` and is
    /// indistinguishable from an absent one. Distinguishing them would mean
    /// re-reading the raw invocation-record JSON, which XCResultKit keeps
    /// internal (`getRootJson` is not public).
    var logFailedToResolve: Bool {
        guard logReference != nil else {
            return false
        }
        guard case .none = logContent else {
            return false
        }
        return true
    }

    /// How this run's log is named in a `Fault` detail.
    ///
    /// The run destination, not the reference: the reference is
    /// backend-internal (a CAS id on legacy, a `--type` selector on modern),
    /// so naming the fault after it would make one degradation read
    /// differently on each backend. The display name is the same fact on both.
    var logFaultDescription: String {
        "log for run \(runDestination.name)"
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
            "LOG_SOURCE": (logSource ?? "").stringByEscapingXMLChars,
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
