//
//  Run.swift
//  XCUITestHTMLReport
//
//  Created by Titouan van Belle on 21.10.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation

struct Run: HTML
{
    private let activityLogsFilename = "action.xcactivitylog"

    var runDestination: RunDestination
    var testSummaries: [TestSummary]
    var status: Status {
       return testSummaries.reduce(true, { (accumulator: Bool, summary: TestSummary) -> Bool in
            return accumulator && summary.status == .success
        }) ? .success : .failure
    }

    init(root: String, path: String)
    {
        let fullpath = root + "/" + path
        Logger.step("Parsing summary")
        Logger.substep("Found summary at \(fullpath)")
        let dict = NSDictionary(contentsOfFile: fullpath)

        guard dict != nil else {
            Logger.error("Failed to parse the content of \(fullpath)")
            exit(EXIT_FAILURE)
        }

        runDestination = RunDestination(dict: dict!["RunDestination"] as! [String : Any])

        let testableSummaries = dict!["TestableSummaries"] as! [[String: Any]]
        testSummaries = testableSummaries.map { TestSummary(root: path.dropLastPathComponent(), dict: $0) }

        Logger.substep("Parsing Activity Logs")
        let parentDirectory = fullpath.dropLastPathComponent()
        Logger.substep("Searching for \(activityLogsFilename) in \(parentDirectory)")

        let logsPath = parentDirectory + "/" + activityLogsFilename

        if !FileManager.default.fileExists(atPath: logsPath) {
            Logger.warning("Failed to find \(activityLogsFilename) in \(parentDirectory). Not appending activity logs to report.")
        } else {

            Logger.substep("Found \(logsPath)")

            let data = NSData(contentsOfFile: logsPath)

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
                return
            }

            let pattern = "Test Suite '.+' (failed|passed).+\r.+seconds"
            let regex = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let matches = regex.matches(in: logs, options: [], range: NSRange(location: 0, length: logs.count))
            let lastMatch = matches.last

            guard lastMatch != nil else {
                Logger.warning("Failed to extract activity logs. Could not locate match for \"\(pattern)\" ")
                return
            }

            let startIndex = lastRunningTestsMatch!.range.location
            let endIndex = lastMatch!.range.location + lastMatch!.range.length
            let start = logs.index(logs.startIndex, offsetBy: startIndex)
            let end = logs.index(logs.startIndex, offsetBy: endIndex)
            let range = start..<end
            let activityLogs = logs.substring(with: range)

            do {
                let file = "\(result.value!)/logs-\(runDestination.targetDevice.identifier).txt"
                try activityLogs.write(toFile: file, atomically: false, encoding: .utf8)
            }
            catch let e {
                Logger.error("An error has occured while create the activity log file. Error: \(e)")
            }
        }
    }

    // PRAGMA MARK: - HTML

    var htmlTemplate = HTMLTemplates.run

    var htmlPlaceholderValues: [String: String] {
        return [
            "DEVICE_IDENTIFIER": runDestination.targetDevice.identifier,
            "TEST_SUMMARIES": testSummaries.map { $0.html }.first!
        ]
    }

}
