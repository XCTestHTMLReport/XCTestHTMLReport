//
//  Test.swift
//  XCTestHTMLReport
//
//  Created by Titouan van Belle on 21.07.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation

enum Status: String {
    case unknown = ""
    case failure = "Failure"
    case success = "Success"

    var cssClass: String {
        switch self {
        case .failure:
            return "failed"
        case .success:
            return "succeeded"
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
    var uuid: String
    var identifier: String
    var duration: Double
    var name: String
    var subTests: [Test]?
    var activities: [Activity]?
    var status: Status
    var objectClass: ObjectClass
    var testScreenshotFlow: TestScreenshotFlow?

    var allSubTests: [Test]? {
        guard subTests != nil else {
            return nil
        }

        return subTests!.compactMap({ (test) -> [Test]? in
            guard test.allSubTests != nil else {
                return [test]
            }

            return test.allSubTests
        }).flatMap { $0 }
    }

    var amountSubTests: Int {
        if let subTests = subTests {
            let a = subTests.reduce(0) { $0 + $1.amountSubTests }
            return a == 0 ? subTests.count : a
        }

        return 0
    }

    init(screenshotsPath: String, dict: [String : Any]) {
        uuid = dict["TestSummaryGUID"] as? String ?? NSUUID().uuidString
        duration = dict["Duration"] as! Double
        name = dict["TestName"] as! String
        identifier = dict["TestIdentifier"] as! String

        let objectClassRaw = dict["TestObjectClass"] as! String
        objectClass = ObjectClass(rawValue: objectClassRaw)!

        if let rawSubTests = dict["Subtests"] as? [[String : Any]] {
            subTests = rawSubTests.map { Test(screenshotsPath: screenshotsPath, dict: $0) }
        }

        if let rawActivitySummaries = dict["ActivitySummaries"] as? [[String : Any]] {
            activities = rawActivitySummaries.map { Activity(screenshotsPath: screenshotsPath, dict: $0, padding: 20) }
        }

        let rawStatus = dict["TestStatus"] as? String ?? ""
        status = Status(rawValue: rawStatus)!
        testScreenshotFlow = TestScreenshotFlow(activities: activities)
    }

    // PRAGMA MARK: - HTML

    var htmlTemplate = HTMLTemplates.test

    var htmlPlaceholderValues: [String: String] {
        return [
            "UUID": uuid,
            "NAME": name + (amountSubTests > 0 ? " - \(amountSubTests) tests" : ""),
            "TIME": duration.timeString,
            "SUB_TESTS": subTests?.accumulateHTMLAsString ?? "",
            "HAS_ACTIVITIES_CLASS": (activities == nil) ? "no-drop-down" : "",
            "ACTIVITIES": activities?.accumulateHTMLAsString ?? "",
            "ICON_CLASS": status.cssClass,
            "ITEM_CLASS": objectClass.cssClass,
			"LIST_ITEM_CLASS": objectClass == .testSummary ? (status == .failure ? "list-item list-item-failed" : "list-item") : "",
            "SCREENSHOT_FLOW": testScreenshotFlow?.screenshots.accumulateHTMLAsString ?? ""
        ]
    }
}
