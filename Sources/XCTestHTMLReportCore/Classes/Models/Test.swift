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
    case mixed   = "Mixed"

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

struct Test: HTML
{
    internal init(uuid: String,
                  identifier: String,
                  duration: Double,
                  name: String,
                  subTests: [Test],
                  activities: [Activity],
                  status: Status,
                  objectClass: ObjectClass,
                  testScreenshotFlow: TestScreenshotFlow?,
                  repetitionPolicy: ActionTestRepetitionPolicySummary?,
                  htmlTemplate: String = HTMLTemplates.test
    ) {
        self.uuid = uuid
        self.identifier = identifier
        self.duration = duration
        self.name = name
        self.subTests = subTests
        self.activities = activities
        self.status = status
        self.objectClass = objectClass
        self.testScreenshotFlow = testScreenshotFlow
        self.repetitionPolicy = repetitionPolicy
        self.htmlTemplate = htmlTemplate
    }
    
    let uuid: String
    let identifier: String
    let duration: Double
    let name: String
    let subTests: [Test]
    let activities: [Activity]
    let status: Status
    let objectClass: ObjectClass
    let testScreenshotFlow: TestScreenshotFlow?
    let repetitionPolicy: ActionTestRepetitionPolicySummary?

    var allSubTests: [Test] {
        return subTests.flatMap { test -> [Test] in
            return test.allSubTests.isEmpty
                ? [test]
                : test.allSubTests
        }
    }

    var amountSubTests: Int {
        let a = subTests.reduce(0) { $0 + $1.amountSubTests }
        return a == 0 ? subTests.count : a
    }

    init(group: ActionTestSummaryGroup, file: ResultFile, renderingMode: Summary.RenderingMode) {
        self.uuid = NSUUID().uuidString
        self.identifier = group.identifier ?? "---identifier-not-found---"
        self.duration = group.duration
        self.name = group.name ?? "---group-name-not-found---"
        if group.subtests.isEmpty {
            self.subTests = group.subtestGroups.map { Test(group: $0, file: file, renderingMode: renderingMode) }
        } else {
            let subTests = group.subtests.reduce(into: Set<Test>()) { subTestSet, actionTestMetadata in
                let t = Test(metadata: actionTestMetadata, file: file, renderingMode: renderingMode)
                if let curTestIndex = subTestSet.firstIndex(of: t) {
                    // If the test identifier already exists in the set, it likely means that the test has a retry policy
                    let curTest = subTestSet[curTestIndex]
                    let newTest = Test(uuid: NSUUID().uuidString,
                                       identifier: t.identifier,
                                       duration: t.duration + curTest.duration,
                                       name: t.name,
                                       subTests: [t] + (curTest.subTests.count > 0 ? curTest.subTests : [curTest]),
                                       activities: [],
                                       status: t.status, // Combine statuses
                                       objectClass: t.objectClass,
                                       testScreenshotFlow: nil,
                                       repetitionPolicy: t.repetitionPolicy)
                    subTestSet.update(with: newTest)
                } else {
                    subTestSet.insert(t)
                }
            }
            self.subTests = Array(subTests)
        }
        self.objectClass = .testSummaryGroup
        self.activities = []
        self.repetitionPolicy = nil
        self.status = .unknown // ???: Usefull?
        testScreenshotFlow = TestScreenshotFlow(activities: activities)
    }

    init(metadata: ActionTestMetadata, file: ResultFile, renderingMode: Summary.RenderingMode) {
        self.uuid = NSUUID().uuidString
        self.identifier = metadata.identifier
        self.duration = metadata.duration ?? 0
        self.name = metadata.name
        self.subTests = []
        self.status = Status(rawValue: metadata.testStatus) ?? .failure
        self.objectClass = .testSummary
        if let id = metadata.summaryRef?.id,
            let actionTestSummary = file.getActionTestSummary(id: id) {
            self.repetitionPolicy = actionTestSummary.repetitionPolicySummary
            self.activities = actionTestSummary.activitySummaries.map {
                Activity(summary: $0, file: file, padding: 20, renderingMode: renderingMode)
            }
        } else {
            self.activities = []
            self.repetitionPolicy = nil
        }
        testScreenshotFlow = TestScreenshotFlow(activities: activities)
    }

    // PRAGMA MARK: - HTML

    var htmlTemplate = HTMLTemplates.test

    var htmlPlaceholderValues: [String: String] {
        return [
            "UUID": uuid,
            "NAME": {
                if let repetitionPolicy = repetitionPolicy, subTests.count > 0 {
                    let passedCt = subTests.filter { $0.status == .success }.count
                    let failedCt = subTests.filter { $0.status == .failure }.count
                    return "\(name) - \(passedCt) passed, \(failedCt) failed"
                }

                return name + (amountSubTests > 0 ? " - \(amountSubTests) tests" : "")
            }(),
            "TIME": duration.timeString,
            "SUB_TESTS": subTests.reduce("") { (accumulator: String, test: Test) -> String in
                return accumulator + test.html
            },
            "HAS_ACTIVITIES_CLASS": activities.isEmpty ? "no-drop-down" : "",
            "ACTIVITIES": activities.accumulateHTMLAsString,
            "ICON_CLASS": status.cssClass,
            "ITEM_CLASS": objectClass.cssClass,
			"LIST_ITEM_CLASS": objectClass == .testSummary ? (status == .failure ? "list-item list-item-failed" : "list-item") : "",
            "SCREENSHOT_FLOW": testScreenshotFlow?.screenshots.accumulateHTMLAsString ?? "",
            "SCREENSHOT_TAIL": testScreenshotFlow?.screenshotsTail.accumulateHTMLAsString ?? ""
        ]
    }
}

extension Test: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }
    
    static func == (lhs: Test, rhs: Test) -> Bool {
        lhs.identifier == rhs.identifier
    }
}

