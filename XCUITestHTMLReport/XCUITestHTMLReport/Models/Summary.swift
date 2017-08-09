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
    private let activityLogsFilename = "action.xcactivitylog"

    var runDestination: RunDestination
    var testSummaries: [TestSummary]
    var activityLogs: String?

    init(root: String)
    {
        Logger.step("Parsing Test Summaries")
        let enumerator = FileManager.default.enumerator(atPath: root)

        guard enumerator != nil else {
            Logger.error("Failed to create enumerator for path \(root)")
            exit(EXIT_FAILURE)
        }

        let paths = enumerator?.allObjects as! [String]

        Logger.substep("Searching for \(filename) in \(root)")
        let plistPath = paths.filter{$0.contains("action_TestSummaries.plist")}

        if plistPath.count == 0 {
            Logger.error("Failed to find action_TestSummaries.plist in \(root)")
            exit(EXIT_FAILURE)
        }

        if plistPath.count > 1 {
            Logger.error("Found multiple action_TestSummaries.plist in \(root)")
            exit(EXIT_FAILURE)
        }

        let testSummariesFullPath = root + "/" + plistPath.first!
        Logger.substep("Found \(filename) at path: \(testSummariesFullPath)")

        let dict = NSDictionary(contentsOfFile: testSummariesFullPath)

        guard dict != nil else {
            Logger.error("Failed to parse the content of \(testSummariesFullPath)")
            exit(EXIT_FAILURE)
        }

        runDestination = RunDestination(dict: dict!["RunDestination"] as! [String : Any])
        let testableSummaries = dict!["TestableSummaries"] as! [[String: Any]]
        testSummaries = testableSummaries.map { TestSummary(dict: $0) }

        Logger.step("Parsing Activity Logs")
        Logger.substep("Searching for \(activityLogsFilename) in \(root)")

        let logsPath = paths.filter{ $0.contains(activityLogsFilename) }

        if logsPath.count == 0 {
            Logger.warning("Failed to find \(activityLogsFilename) in \(root). Not appending activity logs to report.")
        } else {
            if logsPath.count > 1 {
                Logger.warning("Found multiple \(activityLogsFilename) in \(root). Not appending activity logs to report.")
            } else {
                let logsPathFullPath = root + "/" + logsPath.first!

                Logger.substep("Found \(activityLogsFilename) at path: \(logsPathFullPath)")

                let data = NSData(contentsOfFile: logsPathFullPath)

                Logger.substep("Gunzipping activity logs")
                let gunzippedData = data!.gunzipped()!
                let logs = String(data: gunzippedData, encoding: .utf8)!

                Logger.substep("Extracting useful activity logs")
                let runningTestsPattern = "Running tests..."
                let runningTestsRegex = try! NSRegularExpression(pattern: runningTestsPattern, options: .caseInsensitive)
                let runningTestsMatches = runningTestsRegex.matches(in: logs, options: [], range: NSRange(location: 0, length: logs.count))
                let lastRunningTestsMatch = runningTestsMatches.last

                guard lastRunningTestsMatch != nil else {
                    Logger.warning("Failed to extract activity logs. Could not locate match for \"\(runningTestsPattern)\" ")
                    activityLogs = ""
                    return
                }

                let pattern = "Test Suite '.+' (failed|passed).+\r.+seconds"
                let regex = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                let matches = regex.matches(in: logs, options: [], range: NSRange(location: 0, length: logs.count))
                let lastMatch = matches.last

                guard lastMatch != nil else {
                    Logger.warning("Failed to extract activity logs. Could not locate match for \"\(pattern)\" ")
                    activityLogs = ""
                    return
                }

                let startIndex = lastRunningTestsMatch!.range.location
                let endIndex = lastMatch!.range.location + lastMatch!.range.length
                let start = logs.index(logs.startIndex, offsetBy: startIndex)
                let end = logs.index(logs.startIndex, offsetBy: endIndex)
                let range = start..<end
                activityLogs = logs.substring(with: range)
            }
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

