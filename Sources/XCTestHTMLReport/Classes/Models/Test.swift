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

    var cssClass: String {
        switch self {
        case .failure:
            return "failed"
        case .success:
            return "succeeded"
        case .skipped:
            return "skipped"
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
    private(set) var uuid: String
    let identifier: String
    let duration: Double
    let name: String
    let subTests: [Test]
    private(set) var activities: [Activity]
    let status: Status
    let objectClass: ObjectClass
    let summaryGroup: ActionTestSummaryGroup
    private(set) var testScreenshotFlow: TestScreenshotFlow?

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
        self.identifier = group.identifier
        self.duration = group.duration
        self.name = group.name
        if group.subtests.isEmpty {
            self.subTests = group.subtestGroups.map { Test(group: $0, file: file, renderingMode: renderingMode) }
        } else {
            self.subTests = group.subtests.map { Test(group: group, metadata: $0, file: file, renderingMode: renderingMode) }
        }
        self.objectClass = .testSummaryGroup
        self.activities = []
        self.status = .unknown // ???: Usefull?
        self.summaryGroup = group
        testScreenshotFlow = TestScreenshotFlow(activities: activities)
    }

    init(group: ActionTestSummaryGroup, metadata: ActionTestMetadata, file: ResultFile, renderingMode: Summary.RenderingMode) {
        self.uuid = NSUUID().uuidString
        self.identifier = metadata.identifier
        self.duration = metadata.duration ?? 0
        self.name = metadata.name
        self.subTests = []
        self.status = Status(rawValue: metadata.testStatus) ?? .failure
        self.objectClass = .testSummary
        if let id = metadata.summaryRef?.id,
            let actionTestSummary = file.getActionTestSummary(id: id) {
            self.activities = actionTestSummary.activitySummaries.map {
                Activity(summary: $0, file: file, padding: 20, renderingMode: renderingMode)
            }
        } else {
            self.activities = []
        }
        self.summaryGroup = group
        testScreenshotFlow = TestScreenshotFlow(activities: activities)
    }

    func removingScreenshotFlow() -> Test {
        var test = self

        test.testScreenshotFlow = nil

        return test
    }

    func regeneratingUUID() -> Test {
        var test = self

        test.uuid = UUID().uuidString
        test.activities = test.activities.map { $0.regeneratingUUID() }

        return test
    }

    // PRAGMA MARK: - HTML

    var htmlTemplate = HTMLTemplates.test

    var htmlPlaceholderValues: [String: String] {
        return [
            "UUID": uuid,
            "NAME": name + (amountSubTests > 0 ? " - \(amountSubTests) tests" : ""),
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
