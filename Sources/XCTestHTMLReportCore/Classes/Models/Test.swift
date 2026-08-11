//
//  Test.swift
//  XCTestHTMLReport
//
//  Created by Titouan van Belle on 21.07.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation
import XCResultKit

enum Status: String {
    case unknown = ""
    case failure = "Failure"
    case success = "Success"
    case skipped = "Skipped"
    case mixed = "Mixed"

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
        default:
            return ""
        }
    }
}

/// Will be deprecated as each case is now a unique object
enum ObjectClass: String {
    case unknwown = ""
    case testableSummary = "IDESchemeActionTestableSummary"
    case testSummary = "IDESchemeActionTestSummary"
    case testSummaryGroup = "IDESchemeActionTestSummaryGroup"

    var cssClass: String {
        switch self {
        case .testSummary:
            return "test-summary"
        case .testSummaryGroup:
            return "test-summary-group"
        case .testableSummary:
            return "testable-summary"
        default:
            return ""
        }
    }
}

/// A grouping of test cases, typically representing a single XCTestCase class or test suite
public struct TestGroup: Test {
    let uuid: String
    let title: String
    let identifier: String
    let objectClass: ObjectClass = .testSummaryGroup
    let duration: TimeInterval
    var status: Status {
        if subTests.allSatisfy({ $0.status == .success }) {
            return .success
        }

        for s: Status in [.failure, .mixed, .skipped] {
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
        group: ActionTestSummaryGroup,
        identifierPath: IdentifierPath,
        resultFile: ResultFile,
        renderingMode: Summary.RenderingMode,
        downsizeImagesEnabled: Bool,
        downsizeScaleFactor: CGFloat
    ) {
        title = group.name ?? "---group-name-not-found---"
        identifier = group.identifier ?? "---group-identifier-not-found---"
        duration = group.duration
        uuid = identifierPath.appending(identifier).identifier

        Logger.substep("Initializing TestGroup \(identifier)")

        if !group.subtests.isEmpty {
            let operationQueue = OperationQueue()
            operationQueue.maxConcurrentOperationCount = ProcessInfo.processInfo.processorCount * 2
            let queue = DispatchQueue(label: "com.xchtmlreport.subtest.lock")
            var subTestSet: Set<TestCase> = []

            for (sourceIndex, metadata) in group.subtests.enumerated() {
                let operation = BlockOperation {
                    let newTest = TestCase(
                        metadata: metadata,
                        sourceIndex: sourceIndex,
                        identifierPath: identifierPath,
                        resultFile: resultFile,
                        renderingMode: renderingMode,
                        downsizeImagesEnabled: downsizeImagesEnabled,
                        downsizeScaleFactor: downsizeScaleFactor
                    )
                    queue.sync {
                        guard let index = subTestSet.firstIndex(of: newTest) else {
                            subTestSet.insert(newTest)
                            return
                        }
                        var existingTest = subTestSet[index]
                        existingTest.merge(newTest)
                        subTestSet.update(with: existingTest)
                    }
                }
                operationQueue.addOperation(operation)
            }

            operationQueue.waitUntilAllOperationsAreFinished()

            // `Set` iteration order is seeded per process, so this sort has to
            // be a total order or the rendered order changes between runs. Test
            // identifiers are unique here — they are the set's own dedupe key —
            // which makes them a sufficient tiebreaker for equal titles.
            subTests += subTestSet
                .sorted(by: { ($0.title, $0.identifier) < ($1.title, $1.identifier) })
        }

        if !group.subtestGroups.isEmpty {
            subTests += group.subtestGroups.enumerated().map { index, subGroup in TestGroup(
                group: subGroup,
                identifierPath: identifierPath.appending("group\(index)"),
                resultFile: resultFile,
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
            "TITLE": title,
            "DURATION": duration.formattedSeconds,
            "ICON_CLASS": status.cssClass,
            "ITEM_CLASS": objectClass.cssClass,
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

    /// Where this test case sits in the report, kept so that iteration
    /// identifiers can be reassigned once iterations from a repeated run have
    /// been merged in and re-sorted.
    private let identifierPath: IdentifierPath

    var objectClass: ObjectClass = .testSummary
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

    /// This should be the only mutable property
    var iterations: [Iteration]

    init(
        metadata: ActionTestMetadata,
        sourceIndex: Int,
        identifierPath: IdentifierPath,
        resultFile: ResultFile,
        renderingMode: Summary.RenderingMode,
        downsizeImagesEnabled: Bool,
        downsizeScaleFactor: CGFloat
    ) {
        title = metadata.name ?? ""
        identifier = metadata.identifier ?? ""
        // Keyed on the test identifier rather than on position: `TestGroup`
        // dedupes its cases on exactly that, so it is unique among a group's
        // cases, and it survives the merging that position would not.
        self.identifierPath = identifierPath.appending("case").appending(identifier)
        uuid = self.identifierPath.identifier

        Logger.substep("Initializing TestCase \(identifier)")

        iterations = [Iteration(
            metadata: metadata,
            sourceIndex: sourceIndex,
            resultFile: resultFile,
            renderingMode: renderingMode,
            downsizeImagesEnabled: downsizeImagesEnabled,
            downsizeScaleFactor: downsizeScaleFactor
        )]
        assignIterationIdentifiers()
    }

    /// Folds another run of this same test into this one's iterations.
    ///
    /// `other` is the same test — callers reach this through the `Set` that
    /// dedupes on `identifier` — so both sides share an `identifierPath` and
    /// the merged iterations can simply be renumbered.
    mutating func merge(_ other: TestCase) {
        iterations.append(contentsOf: other.iterations)
        // Repetition numbers are not necessarily distinct (older bundles have
        // none at all), and the iterations arrive in whatever order the
        // operations finished in — so break ties on source position to keep
        // this a total order.
        iterations.sort(by: {
            ($0.repetitionPolicy?.iteration ?? 0, $0.sourceIndex) <
                ($1.repetitionPolicy?.iteration ?? 0, $1.sourceIndex)
        })
        assignIterationIdentifiers()
    }

    /// Numbers the iterations by their rendered position.
    ///
    /// Must run again after iterations are merged in from a repeated run:
    /// merging changes both which iterations are present and their order, and
    /// each `iterations-<uuid>` element the page toggles has to stay unique.
    private mutating func assignIterationIdentifiers() {
        for index in iterations.indices {
            iterations[index].uuid = identifierPath.appending("iteration\(index)").identifier
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
                "TITLE": title,
                "DURATION": duration.formattedSeconds,
                "ICON_CLASS": status.cssClass,
                "ITEM_CLASS": objectClass.cssClass,
                "SCREENSHOT_TAIL": iteration.testScreenshotFlow?.screenshotsTail
                    .accumulateHTMLAsString ?? "",
                "SCREENSHOT_FLOW": iteration.testScreenshotFlow?.screenshots
                    .accumulateHTMLAsString ?? "",
                "ACTIVITIES": iteration.activities.accumulateHTMLAsString,
            ]
        } else {
            return [
                "UUID": uuid,
                "TITLE": title,
                "DURATION": duration.formattedSeconds,
                "ICON_CLASS": status.cssClass,
                "ITEM_CLASS": objectClass.cssClass,
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

/// Needed to dedupe iterations
extension TestCase: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.identifier == rhs.identifier
    }
}

extension TestCase: ContainingAttachment {
    var allAttachments: [Attachment] {
        iterations.map(\.allAttachments).reduce([], +)
    }
}
