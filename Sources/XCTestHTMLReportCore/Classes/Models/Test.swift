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
    let uuid: String
    let identifier: String
    let duration: Double
    let name: String
    var subTests: [Test]
    let activities: [Activity]
    let status: Status
    let objectClass: ObjectClass
    let testScreenshotFlow: TestScreenshotFlow?

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
            self.subTests = group.subtests.map { Test(metadata: $0, file: file, renderingMode: renderingMode) }
            
        }
        self.objectClass = .testSummaryGroup
        self.activities = []
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
            self.activities = actionTestSummary.activitySummaries.map {
                Activity(summary: $0, file: file, padding: 20, renderingMode: renderingMode)
            }
        } else {
            self.activities = []
        }
        testScreenshotFlow = TestScreenshotFlow(activities: activities)
        subTests = removeDuplicateElements(testcases: self.subTests)
    }

    // PRAGMA MARK: - HTML

    var htmlTemplate = HTMLTemplates.test

    var htmlPlaceholderValues: [String: String] {
        return [
            "UUID": uuid,
            ///"NAME": name + (amountSubTests > 0 ? " - \(amountSubTests) tests" : ""),
            "NAME": name + (" - \(subTests.count) tests"),
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
    
    func removeDuplicateElements(testcases: [Test]) -> [Test] {
        print("running removeDuplicateElements")
        var uniqueTests = [Test]()
        for testcase in testcases {
            print("testcase.identifier is \(testcase.identifier)")
            print("testcase.name is \(testcase.name)")
            print("testcase.activities is \(testcase.activities)")
            print("testcase.uuid is \(testcase.uuid)")
            print("testcase.subTests is \(testcase.subTests)")
            print("testcase.subTests count is \(testcase.subTests.count)")
            print("testcase.objectClass is \(testcase.objectClass)")
            print("testcase.status is \(testcase.status)")
            print("testcase.testScreenshotFlow is \(testcase.testScreenshotFlow)")
            if !uniqueTests.contains(where: {$0.identifier == testcase.identifier && $0.objectClass == .testSummary }) {
                uniqueTests.append(testcase)
            }
        }
        return uniqueTests
    }
}
