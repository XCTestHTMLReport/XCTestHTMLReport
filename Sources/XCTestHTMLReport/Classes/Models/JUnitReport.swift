//
//  JUnit.swift
//  XCTestHTMLReport
//
//  Created by Chris Ballinger on 4/25/18.
//  Copyright © 2018 Tito. All rights reserved.
//

import Foundation

struct JUnitReport
{
    var name: String
    var tests: Int {
        return suites.map { $0.tests }.reduce(0, { $0 + $1 })
    }
    var failures: Int {
        return suites.map { $0.failures }.reduce(0, { $0 + $1 })
    }
    var suites: [TestSuite]

    struct TestSuite {
        var name: String
        var tests: Int
        var failures: Int {
            return cases.filter { $0.state == .failed }.count
        }
        var cases: [TestCase]
    }

    struct TestCase {
        enum State {
            case unknown
            case failed
            case passed
            case skipped
            case errored
        }
        var classname: String
        var name: String
        var time: TimeInterval
        var state: State
        var results: [TestResult]
    }

    struct TestResult {
        enum State {
            case unknown
            case failed
            case systemOut
            case skipped
        }
        var title: String
        var state: State
    }
}

extension JUnitReport: XMLRepresentable
{
    /// e.g. <testsuites name='BonMot-iOSTests.xctest' tests='990' failures='2'>
    var xmlString: String {
        var xml = "<?xml version='1.0' encoding='UTF-8'?>\n"
        xml += "<testsuites name='\(name)' tests='\(tests)' failures='\(failures)'>\n"

        suites.forEach { (suite) in
            xml += suite.xmlString
        }

        xml += "</testsuites>\n"

        return xml
    }
}

extension JUnitReport.TestSuite: XMLRepresentable
{
    /// e.g. <testsuite name='AccessTests' tests='1' failures='0'>
    var xmlString: String {
        var xml = "  <testsuite name='\(name)' tests='\(tests)' failures='\(failures)'>\n"

        cases.forEach { (testcase) in
            xml += testcase.xmlString
        }

        xml += "  </testsuite>\n"

        return xml
    }
}

extension JUnitReport.TestCase: XMLRepresentable
{
    /// e.g. <testcase classname='AccessTests' name='testThatThingsThatShouldBePublicArePublic-iPhone8' time='0.007'/>
    var xmlString: String {
        let timeString = String(format: "%.02f", time)
        var xml = "    <testcase classname='\(classname)' name='\(name)' time='\(timeString)'"

        if results.isEmpty {
            xml += "/>\n"
        } else {
            xml += ">\n"
            xml += results.map { $0.xmlString }.joined(separator: "\n")
            xml += "\n    </testcase>\n"
        }
        return xml
    }
}

extension JUnitReport.TestResult: XMLRepresentable
{
    /// e.g.
    ///   <failure message='XCTAssertEqual failed: (&quot;0.0&quot;) is not equal to (&quot;1.0&quot;)'/>
    ///   <system-out>Some message logged to std out</system-out>
    var xmlString: String {
        switch state {
        case .failed:
            return "        <failure message='\(title.stringByEscapingXMLChars)'>\n        </failure>"
        case .systemOut:
            return "        <system-out>\(title.stringByEscapingXMLChars)</system-out>"
        case .skipped:
            return "        <skipped />"
        default:
            // falback to system-out. This is better than printing nothing
            return "        <system-out>\(title.stringByEscapingXMLChars)</system-out>"
        }
    }
}


extension JUnitReport
{
    init(summary: Summary)
    {
        name = "All"
        suites = summary.runs.map { JUnitReport.TestSuite(run: $0) }
    }
}

extension JUnitReport.TestCase
{
    init(run: Run, test: Test)
    {
        let components = test.identifier.components(separatedBy: "/")
        time = test.duration
        name = components.last ?? ""
        classname = (components.first ?? "") + " - " + run.runDestination.deviceInfo

        switch test.status {
        case .failure:
            state = .failed
        case .success:
            state = .passed
        case .skipped:
            state = .skipped
        case .unknown:
            state = .unknown
        }
        // Activities can be nested in infinite levels so here everything should be flatted
        // To replicate cascading we add some indent
        func flatSubActivities(of activity: Activity, indent: Int) -> [JUnitReport.TestResult] {
            let t = activity.subActivities.flatMap { flatSubActivities(of: $0, indent: indent + 1) }
            return [JUnitReport.TestResult(activity: activity, indent: indent)] + t
        }
        results = test.activities.map {
            return flatSubActivities(of: $0, indent: 0)
        }.flatMap { $0 }
    }
}

extension JUnitReport.TestResult
{
    init(activity: Activity, indent: Int)
    {
        title = String(repeating: " ", count: indent * 2) + activity.title
        if activity.type == .assertionFailure {
            state = .failed
        } else if activity.type == .userCreated {
            state = .systemOut
        } else if activity.type == .skippedTest {
            state = .skipped
        } else {
            state = .unknown
        }
    }
}

extension JUnitReport.TestSuite
{
    init(run: Run)
    {
        name = (run.testSummaries.first?.testName ?? "") + " - " + run.runDestination.deviceInfo
        tests = run.numberOfTests
        cases = run.allTests.map { JUnitReport.TestCase(run: run, test: $0) }
    }
}

extension RunDestination
{
    var deviceInfo: String {
        return name + " - " + targetDevice.osVersion
    }
}
