//
//  FailureLocationTests.swift
//
//  Where a failure's file and line come from on the modern reader, across the
//  two ways `xcresulttool` has written them.
//
//  Through Xcode 26 the tests document's `Failure Message` node carries the
//  location as the opening of its `name`
//  (`"FirstSuite.swift:86: XCTAssertTrue failed - Test failed"`). Xcode 27.1
//  moved it into a `sourceLocation` object beside a bare `name`, and every
//  failure title in a report lost its file and line. The fixtures can only
//  ever hold the shape of the Xcode that generated them, so both shapes are
//  pinned here on crafted documents, where they run on every toolchain.
//

import XCTest
@testable import XCTestHTMLReportCore

final class FailureLocationTests: XCTestCase {
    /// Serves one crafted `tests` document and one `activities` document.
    private struct CraftedClient: XCResultToolInvoking {
        let testsJSON: String
        let activitiesJSON: String

        var bundleDescription: String {
            "Crafted.xcresult"
        }

        func run(_: [String]) throws -> Data {
            Data()
        }

        func json<T: Decodable>(_ arguments: [String], as type: T.Type) throws -> T {
            let payload = arguments.contains("activities") ? activitiesJSON : testsJSON
            return try JSONDecoder().decode(type, from: Data(payload.utf8))
        }
    }

    /// The first iteration's activities of a one-test bundle whose test case
    /// carries the given `Failure Message` nodes.
    private func activities(
        messageNodes: String, activitiesJSON: String
    ) throws -> [ParsedActivity] {
        let testsJSON = #"""
        {"devices":[{"deviceId":"D","deviceName":"iPhone","modelName":"iPhone","osVersion":"1.0"}],
         "testNodes":[{"nodeType":"Test Plan","name":"P","children":[
           {"nodeType":"Unit test bundle","name":"B","children":[
             {"nodeType":"Test Suite","name":"S","children":[
               {"nodeType":"Test Case","name":"t()","nodeIdentifier":"S/t()",
                "result":"Failed","children":[\#(messageNodes)]}]}]}]}]}
        """#
        let reader = ModernResultReader(
            client: CraftedClient(testsJSON: testsJSON, activitiesJSON: activitiesJSON),
            payloadStore: nil,
            faultCollector: FaultCollector()
        )
        let result = try XCTUnwrap(reader.read())
        let group = try XCTUnwrap(result.runs.first?.testables.first?.groups.first)
        guard case let .testCase(testCase)? = group.children.first else {
            XCTFail("The crafted document holds exactly one test case")
            return []
        }
        return testCase.iterations[0].activities
    }

    private func text(_ json: String) throws -> String? {
        try ModernResultReader.failureText(
            of: JSONDecoder().decode(TestNode.self, from: Data(json.utf8))
        )
    }

    /// The Xcode 27.1 shape, end to end. The title must come out exactly as
    /// the Xcode 26 tool wrote it — the file's last path component, the line,
    /// the message — and must still claim the activity row, so the failure
    /// keeps its location *and* its timestamp and renders once, not as the
    /// activity row plus an appended twin.
    func testTitleIsRebuiltFromAStructuredSourceLocation() throws {
        let rows = try activities(
            messageNodes: #"""
            {"nodeType":"Failure Message","name":"XCTAssertTrue failed - Test failed",
             "sourceLocation":{"filePath":"/Users/ci/App/UITests/FirstSuite.swift","lineNumber":86}}
            """#,
            activitiesJSON: #"""
            {"testIdentifier":"S/t()","testRuns":[{"activities":[
              {"title":"XCTAssertTrue failed - Test failed","isAssociatedWithFailure":true,
               "startTime":5,"childActivities":[{"title":"","isAssociatedWithFailure":false}]}]}]}
            """#
        )
        XCTAssertEqual(
            rows.map(\.title), ["FirstSuite.swift:86: XCTAssertTrue failed - Test failed"]
        )
        XCTAssertEqual(rows.map(\.isFailure), [true])
        XCTAssertNotNil(rows.first?.start, "The retitled row keeps the activity's timestamp")
    }

    /// The Xcode 26 shape must read exactly as it always has.
    func testAPrefixAlreadyInTheNameIsLeftAlone() throws {
        XCTAssertEqual(
            try text(#"{"nodeType":"Failure Message","name":"F.swift:1: boom"}"#),
            "F.swift:1: boom"
        )
    }

    /// Skip reasons and expected failures ride the same node type with no
    /// location on either toolchain. Expected-failure rows are removed by an
    /// *exact* title match, so inventing a prefix here would leave them in
    /// the report.
    func testAMessageWithNoLocationStaysBare() throws {
        XCTAssertEqual(
            try text(#"{"nodeType":"Failure Message","name":"Test skipped - Test skipped"}"#),
            "Test skipped - Test skipped"
        )
    }

    /// No tool is known to report both, but one that did must not render the
    /// location twice.
    func testALocationIsNotPrefixedTwice() throws {
        XCTAssertEqual(
            try text(#"""
            {"nodeType":"Failure Message","name":"F.swift:1: boom",
             "sourceLocation":{"filePath":"/src/F.swift","lineNumber":1}}
            """#),
            "F.swift:1: boom"
        )
    }

    /// Half a location is not enough to build the prefix from: a file with no
    /// line would produce a string no Xcode ever wrote.
    func testAnIncompleteLocationAddsNothing() throws {
        XCTAssertEqual(
            try text(#"""
            {"nodeType":"Failure Message","name":"boom","sourceLocation":{"filePath":"/src/F.swift"}}
            """#),
            "boom"
        )
        XCTAssertEqual(
            try text(#"""
            {"nodeType":"Failure Message","name":"boom","sourceLocation":{"lineNumber":7}}
            """#),
            "boom"
        )
        XCTAssertNil(try text(#"{"nodeType":"Failure Message"}"#))
    }
}
