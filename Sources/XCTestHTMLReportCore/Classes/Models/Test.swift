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

// Will be deprecated as each case is now a unique object
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
    let uuid = UUID().uuidString
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
        resultFile: ResultFile,
        renderingMode: Summary.RenderingMode,
        downsizeImagesEnabled: Bool,
        downsizeScaleFactor: CGFloat
    ) {
        title = group.name ?? "---group-name-not-found---"
        identifier = group.identifier ?? "---group-identifier-not-found---"
        duration = group.duration

        Logger.substep("Initializing TestGroup \(identifier)")

        if !group.subtests.isEmpty {
          subTests += Array(group.subtests.reduce(into: Set<TestCase>()) { subTestSet, metadata in
            let newTest = TestCase(
              metadata: metadata,
              resultFile: resultFile,
              renderingMode: renderingMode,
              downsizeImagesEnabled: downsizeImagesEnabled,
              downsizeScaleFactor: downsizeScaleFactor
            )
            if let index = subTestSet.firstIndex(of: newTest) {
              var existingTest = subTestSet[index]
              existingTest.iterations.append(contentsOf: newTest.iterations)
              subTestSet.update(with: existingTest)
            } else {
              subTestSet.insert(newTest)
            }
          })
        }

        if !group.subtestGroups.isEmpty {
          subTests += group.subtestGroups.map { TestGroup(
            group: $0,
            resultFile: resultFile,
            renderingMode: renderingMode,
            downsizeImagesEnabled: downsizeImagesEnabled,
            downsizeScaleFactor: downsizeScaleFactor
          ) }
        }
    }
}

extension TestGroup {
    var htmlPlaceholderValues: [String: String] { [
        "UUID": uuid,
        "TITLE": title,
        "DURATION": duration.formattedSeconds,
        "ICON_CLASS": status.cssClass,
        "ITEM_CLASS": objectClass.cssClass,
        "SUB_TESTS": subTests.reduce("") { $0 + $1.html },
    ] }

    var htmlTemplate: String { HTMLTemplates.testGroup }
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
    let uuid = UUID().uuidString
    let title: String
    let identifier: String
    var objectClass: ObjectClass = .testSummary
    var duration: TimeInterval {
        iterations.reduce(0) { $0 + $1.duration }
    }

    // Test case status is computed from the combined statuses of iterations.
    // If all iterations have the same status, the test case will have that status,
    // otherwise the status will report as "mixed".
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

    // This should be the only mutable property
    var iterations: [Iteration]

    init(
        metadata: ActionTestMetadata,
        resultFile: ResultFile,
        renderingMode: Summary.RenderingMode,
        downsizeImagesEnabled: Bool,
        downsizeScaleFactor: CGFloat
    ) {
        title = metadata.name ?? ""
        identifier = metadata.identifier ?? ""

        Logger.substep("Initializing TestCase \(identifier)")

        iterations = [Iteration(
            metadata: metadata,
            resultFile: resultFile,
            renderingMode: renderingMode,
            downsizeImagesEnabled: downsizeImagesEnabled,
            downsizeScaleFactor: downsizeScaleFactor
        )]
    }
}

// HTML conforming
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
                "RESULT_STRING": iterationStatusCount().map { "\($0.value) \($0.key.cssClass)" }
                    .joined(separator: ", "),
                // Add something for repetition policy/results breakdown
            ]
        }
    }

    var htmlTemplate: String {
        iterations.count == 1 ? HTMLTemplates.testCase : HTMLTemplates.testCaseWithIterations
    }
}

// Needed to dedupe iterations
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
