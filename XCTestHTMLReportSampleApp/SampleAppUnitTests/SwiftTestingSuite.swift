//
//  SwiftTestingSuite.swift
//  SampleAppUnitTests
//
//  Added to investigate XCTestHTMLReport's support for Swift Testing
//  results (`import Testing`) as part of #393.
//

import Testing

struct SwiftTestingSuite {
    @Test func additionWorks() {
        #expect(1 + 1 == 2)
    }

    @Test func intentionalFailure() {
        #expect(false, "This Swift Testing test intentionally fails")
    }

    @Test("Tagged multiplication check", .tags(.sampleTag))
    func taggedMultiplication() {
        #expect(2 * 3 == 6)
    }

    /// Exercises the modern format's `Arguments` nodes, which no other test
    /// produces — see Task 8 of the xcresulttool migration plan. Without this,
    /// `ParsedTestCase.arguments` would be a field no fixture populates.
    @Test(arguments: [1, 2, 3])
    func parameterizedAddition(value: Int) {
        #expect(value + 0 == value)
    }

    /// Swift Testing's counterpart to `XCTExpectFailure`. Added alongside
    /// SampleAppUnitTests.testExpectedFailure so the `Expected Failure`
    /// status has coverage from both test frameworks — verify against
    /// `xcresulttool get test-results tests` what this actually records as,
    /// rather than assuming it matches XCTest. See #439.
    @Test func knownIssue() {
        withKnownIssue("Intentional known issue for fixture coverage") {
            #expect(1 == 2, "This known-issue expectation fails on purpose")
        }
    }
}

extension Tag {
    @Tag static var sampleTag: Tag
}
