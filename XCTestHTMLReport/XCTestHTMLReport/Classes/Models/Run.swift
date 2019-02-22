//
//  Run.swift
//  XCTestHTMLReport
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
    var testDesignReviews: [TestDesignReview]
    var status: Status {
       return testSummaries.reduce(true, { (accumulator: Bool, summary: TestSummary) -> Bool in
            return accumulator && summary.status == .success
        }) ? .success : .failure
    }
    var allTests: [Test] {
        let tests = testSummaries.flatMap { $0.tests }
        let subTests = tests.compactMap { (test) -> [Test]? in
            guard test.allSubTests != nil else {
                return [test]
            }

            return test.allSubTests
        }

        return subTests.flatMap { $0 }
    }
    var numberOfTests : Int {
        let a = allTests
        return a.count
    }
    var numberOfPassedTests : Int {
        return allTests.filter { $0.status == .success }.count
    }
    var numberOfFailedTests : Int {
        return allTests.filter { $0.status == .failure }.count
    }

    init(root: String, path: String, indexHTMLRoot: String)
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

        var screenshotsPath = ""
        if root == indexHTMLRoot {
            screenshotsPath = path.dropLastPathComponent()
        } else {
            var indexDiff = 0;
            let pathComponentsA = (indexHTMLRoot as NSString).pathComponents
            let pathComponentsB = (root as NSString).pathComponents

            for index in 0..<min(pathComponentsA.count, pathComponentsB.count) {
                if pathComponentsA[index] == pathComponentsB[index] {
                    indexDiff += 1
                } else {
                    break;
                }
            }

            screenshotsPath = String(repeating: "../", count: pathComponentsB[indexDiff...].count) + pathComponentsB[indexDiff...].joined(separator: "/")
        }

        let testableSummaries = dict!["TestableSummaries"] as! [[String: Any]]
        testSummaries = testableSummaries.map { TestSummary(screenshotsPath: screenshotsPath, dict: $0) }
        testDesignReviews = testableSummaries.map { TestDesignReview(screenshotsPath: screenshotsPath, dict: $0) }
        runDestination.status = status

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
            let runningTestsPattern = "Test Suite '.+' started at"
            let runningTestsRegex = try! NSRegularExpression(pattern: runningTestsPattern, options: .caseInsensitive)
            let runningTestsMatches = runningTestsRegex.matches(in: logs, options: [], range: NSRange(location: 0, length: logs.count))
            let lastRunningTestsMatch = runningTestsMatches.first

            guard lastRunningTestsMatch != nil else {
                Logger.warning("Failed to extract activity logs from \(root). Could not locate match for \"\(runningTestsPattern)\"")
                return
            }

            let pattern = "Test Suite '.+' (failed|passed).+\r.+seconds"
            let regex = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let matches = regex.matches(in: logs, options: [], range: NSRange(location: 0, length: logs.count))
            let lastMatch = matches.last

            guard lastMatch != nil else {
                Logger.warning("Failed to extract activity logs from \(root). Could not locate match for \"\(pattern)\" ")
                return
            }

            let startIndex = lastRunningTestsMatch!.range.location
            let endIndex = lastMatch!.range.location + lastMatch!.range.length
            let start = logs.index(logs.startIndex, offsetBy: startIndex)
            let end = logs.index(logs.startIndex, offsetBy: endIndex)
            let activityLogs = logs[start..<end]

            do {
                let file = "\(result.values.first!)/logs-\(runDestination.targetDevice.uniqueIdentifier).txt"
                try activityLogs.write(toFile: file, atomically: false, encoding: .utf8)
            }
            catch let e {
                Logger.error("An error has occured while create the activity log file for \(root). Error: \(e)")
            }

            generateApplicationLog(from: parentDirectory)
        }
    }

    // PRAGMA MARK: - HTML

    var htmlTemplate = HTMLTemplates.run

    var htmlPlaceholderValues: [String: String] {
        return [
            "DEVICE_IDENTIFIER": runDestination.targetDevice.uniqueIdentifier,
            "N_OF_TESTS": String(numberOfTests),
            "N_OF_PASSED_TESTS": String(numberOfPassedTests),
            "N_OF_FAILED_TESTS": String(numberOfFailedTests),
            "TEST_SUMMARIES": testSummaries.map { $0.html }.joined(),
            "TEST_DESIGN_REVIEW": testDesignReviews.compactMap {
                guard !$0.screenshots.isEmpty else { return nil }
                return $0.html
            }.joined()
        ]
    }

    // MARK: - Private

    private func generateApplicationLog(from parentDirectory: String) {
        // The app log file we are looking for is at :
        // ./Diagnostics/<targetName>-X/<targetName>-X/StandardOutputAndStandardError-<bundleId>
        // where X is a random identifier
        let path = parentDirectory + "/Diagnostics"

        guard let appLogsPath = getPath(
            from: path,
            startingWith: "StandardOutputAndStandardError-"
        ) else {
            return
        }

        let appLogFile = "\(result.values.first!)/app-logs-\(runDestination.targetDevice.uniqueIdentifier).txt"
        do {
            let appLogs = try String(contentsOfFile: appLogsPath)
            try appLogs.write(toFile: appLogFile, atomically: false, encoding: .utf8)
        } catch let e {
            Logger.error("An error has occured while create the application log file for \(path). Error: \(e)")
        }
    }

    private func getPath(from parentPath: String, startingWith prefix: String) -> String? {
        guard
            let enumerator = FileManager.default.enumerator(atPath: parentPath),
            var paths = enumerator.allObjects as? [String] else {
                return nil
        }
        paths = paths.filter { $0.contains(prefix) }

        guard paths.count == 1, let path = paths.first else {
            Logger.error("Should corresponds to a single path")
            return nil
        }
        return parentPath + "/" + path
    }
}
