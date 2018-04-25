//
//  JUnit.swift
//  XCTestHTMLReport
//
//  Created by Chris Ballinger on 4/25/18.
//  Copyright © 2018 Tito. All rights reserved.
//

import Foundation

protocol JUnitRepresentable {
    var junit: JUnit { get }
}

protocol XMLRepresentable {
    var xmlString: String { get }
}


struct JUnit {
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
    }
}

extension JUnit: XMLRepresentable {
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

extension JUnit.TestSuite: XMLRepresentable {
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

extension JUnit.TestCase: XMLRepresentable {
    /// e.g. <testcase classname='AccessTests' name='testThatThingsThatShouldBePublicArePublic-iPhone8' time='0.007'/>
    var xmlString: String {
        var xml = "    <testcase classname='\(classname)' name='\(name)' time='\(time)'"
        if state == .failed {
            xml += ">\n"
            xml += "      <failure/>\n"
            xml += "    </testcase>\n"
        } else {
            xml += "/>\n"
        }
        return xml
    }
}


extension JUnit {
    init(summary: Summary) {
        name = "All"
        suites = summary.runs.map { JUnit.TestSuite(run: $0) }
    }
}

extension JUnit.TestCase {
    init(test: Test) {
        let components = test.identifier.components(separatedBy: "/")
        time = test.duration
        name = components.last ?? ""
        classname = components.first ?? ""
        switch test.status {
        case .failure:
            state = .failed
        case .success:
            state = .passed
        case .unknown:
            state = .unknown
        }
    }
}

extension JUnit.TestSuite {
    init(run: Run) {
        name = (run.testSummaries.first?.testName ?? "") + " - " + run.runDestination.name + " - " + run.runDestination.targetDevice.osVersion
        tests = run.numberOfTests
        cases = run.allTests.map { JUnit.TestCase(test: $0) }
    }
}
