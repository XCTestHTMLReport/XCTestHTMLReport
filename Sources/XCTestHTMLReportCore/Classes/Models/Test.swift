//
//  Test.swift
//  XCTestHTMLReport
//
//  Created by Titouan van Belle on 21.07.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation

/// `CaseIterable` so `StatusCSSClassTests` can assert its table covers every
/// case: a status added without a `cssClass` draws no glyph at all, which is
/// how `.expectedFailure` went unnoticed until #439.
enum Status: String, CaseIterable {
    case unknown = ""
    case failure = "Failure"
    case success = "Success"
    case skipped = "Skipped"
    case mixed = "Mixed"
    case expectedFailure = "Expected Failure"

    init(_ parsed: ParsedStatus) {
        switch parsed {
        case .passed:
            self = .success
        case .failed:
            self = .failure
        case .skipped:
            self = .skipped
        case .expectedFailure:
            // Folded into `.unknown` until #439: with no case of its own an
            // expected failure rendered an empty status class, which the
            // stylesheet draws as a blank cell. Both readers already map
            // xcresult's `Expected Failure` to `ParsedStatus.expectedFailure`
            // (legacy and modern alike), so carrying it through to the
            // renderer costs nothing and diverges neither backend.
            self = .expectedFailure
        case .unknown:
            self = .unknown
        }
    }

    /// The class the stylesheet draws a status glyph from.
    ///
    /// `.unknown` returns a name rather than the empty string it used to:
    /// "no icon at all" and "an icon meaning we do not know" are different
    /// statements, and only the second one is true. Note this is *not* the
    /// same set the header counts use — `Run` buckets on the enum, and
    /// expected failures deliberately land in no bucket.
    var cssClass: String {
        switch self {
        case .failure:
            return "failed"
        case .success:
            return "succeeded"
        case .skipped:
            return "skipped"
        case .mixed:
            return "mixed"
        case .expectedFailure:
            return "expected-failure"
        case .unknown:
            return "unknown"
        }
    }
}

/// What kind of node a row represents, and the CSS class the report's own
/// stylesheet and JavaScript select on.
///
/// Replaces `ObjectClass`, whose raw values were Xcode's internal class names
/// (`IDESchemeActionTestSummaryGroup`). The identifiers were legacy; the class
/// names are the report's own contract, and the filter and collapse scripts
/// both depend on them.
enum NodeKind {
    case testCase
    case group

    var cssClass: String {
        switch self {
        case .testCase: return "test-summary"
        case .group: return "test-summary-group"
        }
    }
}

/// A grouping of test cases, typically representing a single XCTestCase class or test suite
public struct TestGroup: Test {
    let uuid: String
    let title: String
    let identifier: String
    let nodeKind: NodeKind = .group
    let duration: TimeInterval
    var status: Status {
        if subTests.allSatisfy({ $0.status == .success }) {
            return .success
        }

        // Precedence, so `.expectedFailure` sits last: a suite holding a real
        // failure is a failed suite whatever else it holds. Added with the
        // status itself (#439) — without it a suite whose every test is an
        // expected failure fell through to `.unknown`, the one value that
        // means "we could not tell", while each of its rows said otherwise.
        for s: Status in [.failure, .mixed, .skipped, .expectedFailure] {
            if subTests.contains(where: { $0.status == s }) {
                return s
            }
        }

        return .unknown
    }

    var subTests: [Test] = []

    var descendantSubTests: [Test] {
        subTests.flatMap { subTest -> [Test] in
            if let testSummaryGroup = subTest as? TestGroup,
               !testSummaryGroup.subTests.isEmpty
            {
                return testSummaryGroup.descendantSubTests
            }
            return [subTest]
        }
    }

    init(
        group: ParsedGroup,
        identifierPath: IdentifierPath,
        file: PayloadProviding,
        renderingMode: Summary.RenderingMode,
        downsizeImagesEnabled: Bool,
        downsizeScaleFactor: CGFloat
    ) {
        title = group.name
        identifier = group.identifier
        duration = group.duration
        uuid = identifierPath.appending(identifier).identifier

        Logger.substep("Initializing TestGroup \(identifier)")

        let caseChildren: [ParsedTestCase] = group.children.compactMap {
            if case let .testCase(testCase) = $0 {
                return testCase
            }
            return nil
        }
        let groupChildren: [ParsedGroup] = group.children.compactMap {
            if case let .group(subGroup) = $0 {
                return subGroup
            }
            return nil
        }

        if !caseChildren.isEmpty {
            let operationQueue = OperationQueue()
            operationQueue.maxConcurrentOperationCount = ProcessInfo.processInfo.processorCount * 2
            let queue = DispatchQueue(label: "com.xchtmlreport.subtest.lock")
            // Keyed by source position: built concurrently, so the order they
            // land in is whatever order the operations finished in.
            var builtCases = [Int: TestCase]()

            for (index, parsedCase) in caseChildren.enumerated() {
                let operation = BlockOperation {
                    let newTest = TestCase(
                        testCase: parsedCase,
                        identifierPath: identifierPath,
                        file: file,
                        renderingMode: renderingMode,
                        downsizeImagesEnabled: downsizeImagesEnabled,
                        downsizeScaleFactor: downsizeScaleFactor
                    )
                    queue.sync {
                        builtCases[index] = newTest
                    }
                }
                operationQueue.addOperation(operation)
            }

            operationQueue.waitUntilAllOperationsAreFinished()

            // Identifiers are unique among a group's cases — the reader merges
            // repetitions on exactly that key — which makes them a sufficient
            // tiebreaker for equal titles, keeping this sort a total order.
            subTests += builtCases.values
                .sorted(by: { ($0.title, $0.identifier) < ($1.title, $1.identifier) })
        }

        if !groupChildren.isEmpty {
            subTests += groupChildren.enumerated().map { index, subGroup in TestGroup(
                group: subGroup,
                identifierPath: identifierPath.appending("group\(index)"),
                file: file,
                renderingMode: renderingMode,
                downsizeImagesEnabled: downsizeImagesEnabled,
                downsizeScaleFactor: downsizeScaleFactor
            ) }
        }
    }
}

extension TestGroup {
    var htmlPlaceholderValues: [String: String] {
        [
            "UUID": uuid,
            "TITLE": title.stringByEscapingXMLChars,
            "DURATION": duration.formattedSeconds,
            "ICON_CLASS": status.cssClass,
            "ITEM_CLASS": nodeKind.cssClass,
            "SUB_TESTS": subTests.reduce("") { $0 + $1.html },
        ]
    }

    var htmlTemplate: String {
        HTMLTemplates.testGroup
    }
}

extension TestGroup: ContainingAttachment {
    var allAttachments: [Attachment] {
        subTests.map(\.allAttachments).reduce([], +)
    }
}

// MARK: TestCase

/// Generally represents a single test method, the smallest unit of test status when considering
/// "Mixed" results
/// Contains one or more `Iteration`s as defined by the RepetitionPolicy. When only one iteration is
/// present, the activities will be bubbled up to `TestCase`.
struct TestCase: Test {
    let uuid: String
    let title: String
    let identifier: String

    let nodeKind: NodeKind = .testCase
    var duration: TimeInterval {
        iterations.reduce(0) { $0 + $1.duration }
    }

    /// Test case status is computed from the combined statuses of iterations.
    /// If all iterations have the same status, the test case will have that status,
    /// otherwise the status will report as "mixed".
    var status: Status {
        let statusCountMap = iterationStatusCount()

        if statusCountMap.count == 1,
           let first = statusCountMap.first
        {
            return first.key
        }

        return .mixed
    }

    private func iterationStatusCount() -> [Status: Int] {
        if iterations.isEmpty {
            return [.unknown: 1]
        }

        if iterations.count == 1 {
            return [iterations[0].status: 1]
        }

        return iterations.reduce(into: [:]) { map, i in
            map[i.status] = (map[i.status] ?? 0) + 1
        }
    }

    let iterations: [Iteration]

    init(
        testCase: ParsedTestCase,
        identifierPath: IdentifierPath,
        file: PayloadProviding,
        renderingMode: Summary.RenderingMode,
        downsizeImagesEnabled: Bool,
        downsizeScaleFactor: CGFloat
    ) {
        title = testCase.name
        identifier = testCase.identifier
        // Keyed on the test identifier rather than on position: the reader
        // merges a repeated run's entries on exactly that, so it is unique
        // among a group's cases, and it survives merging where position would
        // not.
        let path = identifierPath.appending("case").appending(testCase.identifier)
        uuid = path.identifier

        Logger.substep("Initializing TestCase \(identifier)")

        // The reader already merged repetitions into ordered iterations, so
        // each iteration's rendered position — and with it the
        // `iterations-<uuid>` element id the page toggles — is final here.
        iterations = testCase.iterations.enumerated().map { index, iteration in
            Iteration(
                iteration: iteration,
                identifierPath: path.appending("iteration\(index)"),
                title: testCase.name,
                identifier: testCase.identifier,
                file: file,
                renderingMode: renderingMode,
                downsizeImagesEnabled: downsizeImagesEnabled,
                downsizeScaleFactor: downsizeScaleFactor
            )
        }
    }
}

/// HTML conforming
extension TestCase {
    var htmlPlaceholderValues: [String: String] {
        if iterations.count == 1 {
            let iteration = iterations[0]
            return [
                "UUID": uuid,
                "TITLE": title.stringByEscapingXMLChars,
                "DURATION": duration.formattedSeconds,
                "ICON_CLASS": status.cssClass,
                "ITEM_CLASS": nodeKind.cssClass,
                "SCREENSHOT_TAIL": iteration.testScreenshotFlow?.screenshotsTail
                    .accumulateHTMLAsString ?? "",
                "SCREENSHOT_FLOW": iteration.testScreenshotFlow?.screenshots
                    .accumulateHTMLAsString ?? "",
                "ACTIVITIES": iteration.activities.accumulateHTMLAsString,
            ]
        } else {
            return [
                "UUID": uuid,
                "TITLE": title.stringByEscapingXMLChars,
                "DURATION": duration.formattedSeconds,
                "ICON_CLASS": status.cssClass,
                "ITEM_CLASS": nodeKind.cssClass,
                "ITERATIONS": iterations.reduce("") { $0 + $1.html },
                // Sorted because `Dictionary` iteration order is seeded per
                // process: unsorted, "1 failed, 1 succeeded" renders as
                // "1 succeeded, 1 failed" on some runs and not others.
                "RESULT_STRING": iterationStatusCount()
                    .sorted { $0.key.cssClass < $1.key.cssClass }
                    .map { "\($0.value) \($0.key.cssClass)" }
                    .joined(separator: ", "),
                // Add something for repetition policy/results breakdown
            ]
        }
    }

    var htmlTemplate: String {
        iterations.count == 1 ? HTMLTemplates.testCase : HTMLTemplates.testCaseWithIterations
    }
}

extension TestCase: ContainingAttachment {
    var allAttachments: [Attachment] {
        iterations.map(\.allAttachments).reduce([], +)
    }
}
