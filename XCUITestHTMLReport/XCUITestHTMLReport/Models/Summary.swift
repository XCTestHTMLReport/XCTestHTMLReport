//
//  Summary.swift
//  XCUITestHTMLReport
//
//  Created by Titouan van Belle on 21.07.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation

struct Summary: HTML
{
    private let filename = "action_TestSummaries.plist"

    var runDestination: RunDestination
    var testSummaries: [TestSummary]
    var activityLogs: String

    init(root: String)
    {
        let enumerator = FileManager.default.enumerator(atPath: root)

        guard enumerator != nil else {
            print("Could not find anyfiles")
            exit(EXIT_FAILURE)
        }

        let paths = enumerator?.allObjects as! [String]
        let plistPath = paths.filter{$0.contains("action_TestSummaries.plist")}

        if plistPath.count == 0 {
            print("Could not find action_TestSummaries.plist in \(root)")
            exit(EXIT_FAILURE)
        }

        if plistPath.count > 1 {
            print("Found multiple action_TestSummaries.plist in \(root)")
            exit(EXIT_FAILURE)
        }

        let testSummariesFullPath = root + "/" + plistPath.first!

        let dict = NSDictionary(contentsOfFile: testSummariesFullPath)

        guard dict != nil else {
            print("Failed to parse the content of \(testSummariesFullPath)")
            exit(EXIT_FAILURE)
        }

        runDestination = RunDestination(dict: dict!["RunDestination"] as! [String : Any])
        let testableSummaries = dict!["TestableSummaries"] as! [[String: Any]]
        testSummaries = testableSummaries.map { TestSummary(dict: $0) }


        let logsPath = paths.filter{$0.contains("action.xcactivitylog")}

        if logsPath.count == 0 {
            print("Could not find action.xcactivitylog in \(root)")
            exit(EXIT_FAILURE)
        }

        if logsPath.count > 1 {
            print("Found multiple action.xcactivitylog in \(root)")
            exit(EXIT_FAILURE)
        }

        let logsPathFullPath = root + "/" + logsPath.first!
        let data = NSData(contentsOfFile: logsPathFullPath)
        let gunzippedData = data!.gunzipped()!
        let logs = String(data: gunzippedData, encoding: .utf8)!

        let runningTestsRegex = try! NSRegularExpression(pattern: "Running tests...", options: .caseInsensitive)
        let runningTestsMatches = runningTestsRegex.matches(in: logs, options: [], range: NSRange(location: 0, length: logs.count))
        let lastRunninTestsMatch = runningTestsMatches.last

        let regex = try! NSRegularExpression(pattern: "Test Suite '.+.xctest' (failed|passed).+\r.+seconds", options: .caseInsensitive)
        let matches = regex.matches(in: logs, options: [], range: NSRange(location: 0, length: logs.count))
        let lastMatch = matches.last

        if let matchA = lastRunninTestsMatch, let matchB = lastMatch {
            let startIndex = matchA.range.location
            let endIndex = matchB.range.location + matchB.range.length
            let start = logs.index(logs.startIndex, offsetBy: startIndex)
            let end = logs.index(logs.startIndex, offsetBy: endIndex)
            let range = start..<end
            activityLogs = logs.substring(with: range)
        } else {
            activityLogs = ""
        }
    }

    // PRAGMA MARK: - HTML

    var htmlTemplate = HTMLTemplates.index

    var htmlPlaceholderValues: [String: String] {
        return [
            "DEVICE_NAME": runDestination.name,
            "DEVICE_IDENTIFIER": runDestination.targetDevice.identifier,
            "DEVICE_MODEL": runDestination.targetDevice.model,
            "DEVICE_OS": runDestination.targetDevice.osVersion,
            "RESULT_CLASS": testSummaries.reduce(true, { (accumulator: Bool, summary: TestSummary) -> Bool in
                return accumulator && summary.status == .success
            }) ? "success" : "failure",
            "TEST_SUMMARIES": testSummaries.map { $0.html }.first!,
            
        ]
    }
}

