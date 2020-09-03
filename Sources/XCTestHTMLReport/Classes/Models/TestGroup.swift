//
//  TestGroup.swift
//  XCTestHTMLReport
//
//  Created by Evan Coleman on 9/1/20.
//

import Foundation
import XCResultKit

struct TestGroup: HTML {

    let uuid: String
    let name: String
    let identifier: String
    let duration: Double
    let status: Status
    let tests: [Test]

    var allSubTests: [Test] {
        return tests.flatMap { test -> [Test] in
            return test.allSubTests.isEmpty
                ? [test]
                : test.allSubTests
        }
    }

    init(group: ActionTestSummaryGroup, tests: [Test]) {
        self.uuid = "GROUP-\(UUID().uuidString)"
        self.identifier = group.identifier
        self.duration = tests.reduce(0) { $0 + $1.duration }
        self.name = tests.first?.name ?? group.name
        self.tests = tests
        self.status = tests.first { $0.status == .success } != nil ? .success : tests.last?.status ?? .unknown
    }

    // PRAGMA MARK: - HTML

    var htmlTemplate = HTMLTemplates.testGroup

    var htmlPlaceholderValues: [String: String] {
        return [
            "UUID": uuid,
            "NAME": name + (tests.count > 0 ? " - \(tests.count) \(tests.count == 1 ? "try" : "tries")" : ""),
            "TIME": duration.timeString,
            "TESTS": tests.accumulateHTMLAsString,
            "ICON_CLASS": status.cssClass,
        ]
    }
}
