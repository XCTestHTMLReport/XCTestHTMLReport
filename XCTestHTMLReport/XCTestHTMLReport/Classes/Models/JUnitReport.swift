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

        if state == .failed {
            xml += ">\n"
            xml += "      <failure>\n"

            results.forEach { (result) in
                xml += result.xmlString
            }

            xml += "      </failure>\n"
            xml += "    </testcase>\n"
        } else {
            xml += "/>\n"
        }

        return xml
    }
}

extension JUnitReport.TestResult: XMLRepresentable
{
    var xmlString: String {
        switch state {
        case .failed:
            return "        \(title.stringByEscapingXMLChars)\n"
        default:
            return ""
        }
    }
}


extension JUnitReport
{
    init(summary: Summary, includeRunDestinationInfo: Bool)
    {
        name = "All"
        suites = summary.runs.map { JUnitReport.TestSuite(run: $0, includeRunDestinationInfo: includeRunDestinationInfo) }
    }
}

extension JUnitReport.TestCase
{
    init(run: Run, test: Test, includeRunDestinationInfo: Bool)
    {
        let components = test.identifier.components(separatedBy: "/")
        time = test.duration
        name = components.last ?? ""

        let baseClassname = components.first ?? ""
        classname = includeRunDestinationInfo ? baseClassname + " - " + run.runDestination.deviceInfo : baseClassname

        switch test.status {
        case .failure:
            state = .failed
        case .success:
            state = .passed
        case .unknown:
            state = .unknown
        }

        results = test.activities?.map { JUnitReport.TestResult(activity: $0) } ?? []
    }
}

extension JUnitReport.TestResult
{
    init(activity: Activity)
    {
        title = activity.title

        if activity.type == .assertionFailure {
            state = .failed
        } else {
            state = .unknown
        }
    }
}

extension JUnitReport.TestSuite
{
    init(run: Run, includeRunDestinationInfo: Bool)
    {
        let baseName = run.testSummaries.first?.testName ?? ""
        name = includeRunDestinationInfo ? baseName + " - " + run.runDestination.deviceInfo : baseName
        tests = run.numberOfTests
        cases = run.allTests.map { JUnitReport.TestCase(run: run, test: $0, includeRunDestinationInfo: includeRunDestinationInfo) }
    }
}

extension RunDestination
{
    var deviceInfo: String {
        return name + " - " + targetDevice.osVersion
    }
}
