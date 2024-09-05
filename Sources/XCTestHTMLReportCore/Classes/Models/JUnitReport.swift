//
//  JUnit.swift
//  XCTestHTMLReport
//
//  Created by Chris Ballinger on 4/25/18.
//  Copyright © 2018 Tito. All rights reserved.
//

import Foundation

struct JUnitReport {
    var name: String
    var tests: Int {
        suites.map(\.tests).reduce(0) { $0 + $1 }
    }

    var failures: Int {
        suites.map(\.failures).reduce(0) { $0 + $1 }
    }
    
    var skipped: Int {
        suites.map(\.skipped).reduce(0) { $0 + $1 }
    }

    var suites: [TestSuite]

    struct TestSuite {
        var name: String
        var tests: Int
        var failures: Int {
            cases.filter { $0.state == .failed }.count
        }
        var skipped: Int {
            cases.filter { $0.state == .skipped }.count
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
            case mixed
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
            // Support error output in teamcity
            // For example, find here how teamcity parses system-err: https://github.com/JetBrains/teamcity-xml-tests-reporting/blob/b86b9336679a04653792b2915af8de4941304c75/agent/src/jetbrains/buildServer/xmlReportPlugin/parsers/antJUnit/AntJUnitXmlReportParser.java#L145
            // For more context see: https://github.com/XCTestHTMLReport/XCTestHTMLReport/pull/280
            case systemErr
            case skipped
        }

        var title: String
        var state: State
    }
}

extension JUnitReport: XMLRepresentable {
    /// e.g. <testsuites name='BonMot-iOSTests.xctest' tests='990' failures='2'>
    var xmlString: String {
        var xml = "<?xml version='1.0' encoding='UTF-8'?>\n"
        xml +=
            "<testsuites name='\(name.stringByEscapingXMLChars)' tests='\(tests)' failures='\(failures)' skipped='\(skipped)'>\n"

        suites.forEach { suite in
            xml += suite.xmlString
        }

        xml += "</testsuites>\n"

        return xml
    }
}

extension JUnitReport.TestSuite: XMLRepresentable {
    /// e.g. <testsuite name='AccessTests' tests='1' failures='0'>
    var xmlString: String {
        var xml =
            "  <testsuite name='\(name.stringByEscapingXMLChars)' tests='\(tests)' failures='\(failures)' skipped='\(skipped)'>\n"

        cases.forEach { testcase in
            xml += testcase.xmlString
        }

        xml += "  </testsuite>\n"

        return xml
    }
}

extension JUnitReport.TestCase: XMLRepresentable {
    /// e.g. <testcase classname='AccessTests'
    /// name='testThatThingsThatShouldBePublicArePublic-iPhone8' time='0.007'/>
    var xmlString: String {
        let timeString = String(format: "%.02f", time)
        var xml =
            "  <testcase classname='\(classname.stringByEscapingXMLChars)' name='\(name.stringByEscapingXMLChars)' time='\(timeString)'"
        
        /// Skipped tests can have no TestResults (logs) so we need to check the status to add the skipped tag to the xml file
        if self.state == .skipped {
            xml += ">\n"
            xml += "    <skipped/>"
            xml += "\n  </testcase>\n"
        } else if results.isEmpty {
            xml += "/>\n"
        } else {
            xml += ">\n"
            xml += results.map(\.xmlString).joined(separator: "\n")
            xml += "\n  </testcase>\n"
        }
        return xml
    }
}

extension JUnitReport.TestResult: XMLRepresentable {
    /// e.g.
    ///   <failure message='XCTAssertEqual failed: (&quot;0.0&quot;) is not equal to
    /// (&quot;1.0&quot;)'/>
    ///   <system-out>Some message logged to std out</system-out>
    var xmlString: String {
        switch state {
        case .failed:
            return "    <failure message='\(title.stringByEscapingXMLChars)'>\n    </failure>"
        case .systemOut:
            return "    <system-out>\(title.stringByEscapingXMLChars)</system-out>"
        case .systemErr:
            return "    <system-err>\(title.stringByEscapingXMLChars)</system-err>"
        case .skipped:
            return "    <skipped />"
        case .unknown:
            // falback to system-out. This is better than printing nothing
            return "    <system-out>\(title.stringByEscapingXMLChars)</system-out>"
        }
    }
}

extension JUnitReport {
    init(summary: Summary, includeRunDestinationInfo: Bool) {
        name = "All"
        suites = summary.runs
            .map {
                JUnitReport.TestSuite(run: $0, includeRunDestinationInfo: includeRunDestinationInfo)
            }
    }
}

private extension JUnitReport.TestCase {
    init(run: Run, test: Test, includeRunDestinationInfo: Bool) {
        let components = test.identifier.components(separatedBy: "/")
        time = test.duration
        name = components.last ?? ""

        var classname = components.first ?? ""
        if includeRunDestinationInfo {
            classname += " - " + run.runDestination.deviceInfo
        }
        self.classname = classname

        switch test.status {
        case .failure:
            state = .failed
        case .success:
            state = .passed
        case .skipped:
            state = .skipped
        case .mixed:
            state = .mixed
        case .unknown:
            state = .unknown
        }
        // Activities can be nested in infinite levels so here everything should be flatted
        // To replicate cascading we add some indent
        func flatSubActivities(
            of activity: Activity,
            indent: Int,
            isFailureFatal: Bool
        ) -> [JUnitReport.TestResult] {
            let t = activity.subActivities
                .flatMap {
                    flatSubActivities(of: $0, indent: indent + 1, isFailureFatal: isFailureFatal)
                }
            return [JUnitReport
                .TestResult(activity: activity, indent: indent, isFailureFatal: isFailureFatal)] + t
        }

        // TODO: Is there any better way to represent multiple iterations in a junit report?
        results = []
        if let testCase = test as? TestCase {
            for (index, iteration) in testCase.iterations.enumerated() {
                let isLastIteration = index == testCase.iterations.indices.last
                results += iteration
                    .activities
                    .map { flatSubActivities(of: $0, indent: 0, isFailureFatal: isLastIteration) }
                    .flatMap { $0 }
            }
        }
    }
}

private extension JUnitReport.TestResult {
    init(activity: Activity, indent: Int, isFailureFatal: Bool) {
        title = String(repeating: " ", count: indent * 2) + activity.title
        if activity.type == .assertionFailure {
            if isFailureFatal {
                state = .failed
            } else {
                state = .systemErr
            }
        } else if activity.type == .userCreated {
            state = .systemOut
        } else if activity.type == .skippedTest {
            state = .skipped
        } else {
            state = .unknown
        }
    }
}

private extension JUnitReport.TestSuite {
    init(run: Run, includeRunDestinationInfo: Bool) {
        var name = run.testSummaries.first?.testName ?? ""
        if includeRunDestinationInfo {
            name += " - " + run.runDestination.deviceInfo
        }
        self.name = name
        tests = run.numberOfTests
        cases = run.allTests
            .map {
                JUnitReport
                    .TestCase(
                        run: run,
                        test: $0,
                        includeRunDestinationInfo: includeRunDestinationInfo
                    )
            }
    }
}

extension RunDestination {
    var deviceInfo: String {
        name + " - " + targetDevice.osVersion
    }
}
