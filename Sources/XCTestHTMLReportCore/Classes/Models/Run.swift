//
//  Run.swift
//  XCTestHTMLReport
//
//  Created by Titouan van Belle on 21.10.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation

struct Run {
    let file: PayloadProviding
    let runDestination: RunDestination
    let testSummaries: [TestSummary]
    let logContent: RenderingContent
    /// The log as text, for the Logs view to render in the page (#439, A3b).
    ///
    /// The log used to be an `<iframe src>`, which put it in a *foreign
    /// document*: a `file://` sibling in linking mode, an opaque `data:` URI
    /// in inline mode. Two consequences, both of which the report shipped:
    ///
    /// - Nothing in the page could act on it. A3a's Logs toolbar therefore had
    ///   an inert "All Messages" label where a control belongs, because no
    ///   control the parent can hold is able to filter, scroll or search across
    ///   an origin boundary.
    /// - It could not see the token layer. In dark mode the Logs view rendered
    ///   as a white slab with black text — the same class of defect as the
    ///   base64 status PNGs #459 replaced with masks, and for the same reason.
    ///
    /// Both go away when the text is in the document. `logContent` is kept and
    /// unchanged: the exported `.log` file is the artifact #480 fixed and
    /// `DifferentialLogTests` compares, and it stays the signal
    /// `logFailedToResolve` reads.
    let logText: String
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

    /// The second of Xcode's two numbers (#439, A3b): 21 tests, 23 runs.
    ///
    /// Summed over the leaves, like every other figure the header and the
    /// toolbar derive, so a suite's own node can never be counted on top of
    /// the cases inside it. Equal to `numberOfTests` on a run that neither
    /// repeated nor parameterized anything, which is most runs — the toolbar
    /// states it either way, because "23 executions" and "21 executions" are
    /// both answers to the question, and a figure that only appears when it
    /// disagrees is a figure a reader cannot learn to look for.
    var numberOfExecutions: Int {
        allTests.reduce(0) { $0 + $1.executionCount }
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

        if let logReference = run.logReference {
            // The bytes first and once, because the rendered text and — in
            // inline mode — the exported content are the same bytes. Only
            // linking mode reads a second time, to write the file, which is
            // why this is spelled out rather than left to `exportLogsContent`.
            let data = file.exportLogsData(reference: logReference)
            // Both readers build this text out of Swift `String`s before it is
            // ever bytes, so it is valid UTF-8 by construction and the failable
            // initializer is the repo's idiom rather than a risk taken here.
            logText = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            switch renderingMode {
            case .inline:
                logContent = data.map(RenderingContent.data) ?? .none
            case .linking:
                logContent = file.exportLogs(
                    reference: logReference,
                    // Named from the run's identifier path, not from
                    // `reference`: the reference is backend-internal (a CAS id
                    // on legacy, a `--type` selector on modern), so a file
                    // named after it can never agree across backends. The path
                    // digest is the same scheme every element id already uses
                    // (#430), identical on both backends, and unique per run —
                    // a multi-action bundle gets one log file per action
                    // instead of a shared name that would leave
                    // last-writer-wins. No fixture exercises multiple actions,
                    // so that property is asserted here rather than in a test.
                    fileName: "\(identifierPath.identifier).log"
                ).map(RenderingContent.url) ?? .none
            }
        } else {
            Logger.warning("Can't find log reference for run \(run.destination.displayName)")
            logText = ""
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

    // PRAGMA MARK: - HTML

    /// A run renders into two places, not one (#439, A3a).
    ///
    /// The shell used to give each run a single pane holding its tree *and*
    /// its log, and switched views by toggling display inside every pane at
    /// once. Per-view surface ownership inverts that: the views are the outer
    /// level, so a run contributes one slice to each. Two consequences worth
    /// stating, because both were bugs before:
    ///
    /// - The views are contiguous regions of the document, which is what lets
    ///   each be a single `tabpanel` a tab can point `aria-controls` at.
    /// - The log's element ids are per destination. Every run used to emit
    ///   `id="logs"`, `id="logs-header"` and `id="logs-iframe"`, so a report
    ///   built from two bundles emitted each of them twice and only behaved
    ///   because the duplicates sat inside a hidden pane.
    ///
    /// `HTML` gives a conformer exactly one template, so `Run` renders through
    /// named properties instead of conforming. The substitution is the
    /// protocol's own — same placeholder syntax, same verbatim-value rule, so
    /// the escaping contract in `HTML`'s documentation still governs every
    /// value below.
    ///
    /// **Ordered, and one list per template** (#439, A3b). `HTML.html` reduces
    /// over a dictionary, so it fills placeholders in whatever order the hash
    /// happens to yield and fills the ones an earlier replacement *inserted*
    /// as readily as the ones the template author wrote — the substitution
    /// hazard the A3a review found in the picker and `PlaceholderOrderTests`
    /// pins. Two per-view templates make it closable here rather than merely
    /// ordered: each list carries only what its own template needs, and the one
    /// value in each that is test-author text goes in last, with nothing after
    /// it to fill. So a test named `[[LOG_TEXT]]` renders as itself (the Tests
    /// list has no such entry) and a log line reading `[[TEST_SUMMARIES]]`
    /// renders as itself, where one shared dictionary in hash order could
    /// substitute either into the other.
    var testsViewHTML: String {
        // Identifier, counts and pills first — every one of them opaque by
        // construction (a digest, an Int, a label from an enum) — then the
        // tree, which is the only value here a test author can write.
        render(HTMLTemplates.runTests, [
            ("DEVICE_IDENTIFIER", runDestination.targetDevice.uniqueIdentifier),
            ("N_OF_TESTS", String(numberOfTests)),
            ("EXECUTIONS_LABEL", Self.executionsLabel(numberOfExecutions)),
            ("FILTER_PILLS", filterPillsHTML),
            ("TEST_SUMMARIES", testSummaries.map(\.html).joined()),
        ])
    }

    var logsViewHTML: String {
        render(HTMLTemplates.runLogs, [
            ("DEVICE_IDENTIFIER", runDestination.targetDevice.uniqueIdentifier),
            ("LOG_LINES_LABEL", Self.linesLabel(logLineCount)),
            ("LOG_TEXT", logText.stringByEscapingXMLChars),
        ])
    }

    private func render(_ template: String, _ values: [(String, String)]) -> String {
        values.reduce(template) { accumulator, entry in
            accumulator.replacingOccurrences(of: "[[\(entry.0)]]", with: entry.1)
        }
    }

    /// Lines as the `<pre>` will show them: a trailing newline ends the last
    /// line rather than starting an empty one, which is what the script's own
    /// count has to agree with or the toolbar states a number the reader
    /// cannot find.
    var logLineCount: Int {
        guard !logText.isEmpty else {
            return 0
        }
        return logText.hasSuffix("\n")
            ? logText.dropLast().components(separatedBy: "\n").count
            : logText.components(separatedBy: "\n").count
    }

    static func executionsLabel(_ count: Int) -> String {
        count == 1 ? "1 execution" : "\(count) executions"
    }

    static func linesLabel(_ count: Int) -> String {
        count == 1 ? "1 line" : "\(count) lines"
    }

    /// The status filter row (#439, A3b).
    ///
    /// The same buckets the summary header's legend draws, in the same order,
    /// under the same drop-the-empty-ones rule — because they are the same
    /// `Tally`. That is the whole of the #460 decision made operable: A1
    /// already gave expected failures a bucket of their own, and the filter row
    /// was the one reading of the run that still had them in no bucket at all,
    /// neither shown by "All" nor hidden by "Passed".
    ///
    /// A leading "All" and then one pill per outcome the run produced. Empty
    /// buckets are dropped for the reason the legend drops them — a permanent
    /// "Mixed (0)" in a report that never retried a test is noise — and
    /// dropping them is also what keeps the row honest as the set of statuses
    /// grows: `unknown` gets a pill exactly when a run contains one, which is
    /// the same gap #460 names, closed for the other status that had it.
    private var filterPillsHTML: String {
        let all = Self.filterPill(
            filter: "all", label: "All", count: numberOfTests, checked: true
        )
        // Joined on a newline at the template's own indentation, so a rendered
        // report — and the committed golden a reviewer reads the diff of —
        // shows one pill per line rather than the whole row as one.
        return ([all] + tally.buckets.map {
            Self.filterPill(
                filter: $0.status.cssClass, label: $0.label, count: $0.count, checked: false
            )
        }).joined(separator: "\n          ")
    }

    /// One pill. `data-filter` carries the row class it selects, so the script
    /// has one mapping from pill to rows instead of five functions naming the
    /// classes over again — and adding a status adds a case to `Status`, not a
    /// function to the page.
    ///
    /// Every value is opaque by construction: a CSS class from an enum, a
    /// literal label, an `Int`.
    private static func filterPill(
        filter: String, label: String, count: Int, checked: Bool
    ) -> String {
        HTMLTemplates.filterPill
            .replacingOccurrences(of: "[[FILTER]]", with: filter)
            .replacingOccurrences(of: "[[CHECKED]]", with: checked ? "true" : "false")
            .replacingOccurrences(of: "[[TABINDEX]]", with: checked ? "0" : "-1")
            .replacingOccurrences(of: "[[LABEL]]", with: label)
            .replacingOccurrences(of: "[[COUNT]]", with: String(count))
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
