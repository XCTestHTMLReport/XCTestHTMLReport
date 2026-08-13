//
//  ModernReaderRuleTests.swift
//
//  Pins the bookkeeping-row rules the first differential run forced into the
//  modern reader — tip-of-chain failure mapping, symbol-annotation and
//  attachment-shadow drops, expected-failure removal, and content-addressed
//  link resolution — on crafted documents where fixtures have no such shape,
//  and on the fixture cases that motivated each rule.
//

import XCTest
@testable import XCTestHTMLReportCore

final class ModernReaderRuleTests: XCTestCase {
    // MARK: - Helpers (mirrors ModernResultReaderTests)

    private func read(_ resource: String) throws -> ParsedResult {
        let url = try XCTUnwrap(
            Bundle.testBundle.url(forResource: resource, withExtension: "xcresult")
        )
        let reader = ModernResultReader(
            client: XCResultToolClient(bundleURL: url),
            payloadStore: nil,
            faultCollector: FaultCollector()
        )
        return try XCTUnwrap(reader.read())
    }

    private func testCases(in result: ParsedResult) -> [ParsedTestCase] {
        func walk(_ node: ParsedNode) -> [ParsedTestCase] {
            switch node {
            case let .group(group): return group.children.flatMap(walk)
            case let .testCase(testCase): return [testCase]
            }
        }
        return result.runs
            .flatMap(\.testables)
            .flatMap(\.groups)
            .flatMap { $0.children.flatMap(walk) }
    }

    private func flattened(_ activities: [ParsedActivity]) -> [ParsedActivity] {
        activities.flatMap { [$0] + flattened($0.subActivities) }
    }

    // MARK: - Bookkeeping-row rules on crafted documents

    /// Serves crafted `tests` and `activities` documents so the translation
    /// rules can be pinned on shapes no fixture happens to produce.
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

    private func craftedCase(
        testsJSON: String, activitiesJSON: String
    ) throws -> ParsedTestCase {
        let reader = ModernResultReader(
            client: CraftedClient(testsJSON: testsJSON, activitiesJSON: activitiesJSON),
            payloadStore: nil,
            faultCollector: FaultCollector()
        )
        return try XCTUnwrap(try testCases(in: XCTUnwrap(reader.read())).first)
    }

    private static func testsDocument(
        result: String, failureMessages: [String]
    ) -> String {
        let messages = failureMessages
            .map { #"{"nodeType":"Failure Message","name":"\#($0)"}"# }
            .joined(separator: ",")
        return #"""
        {"devices":[{"deviceId":"D","deviceName":"iPhone","modelName":"iPhone","osVersion":"1.0"}],
         "testNodes":[{"nodeType":"Test Plan","name":"P","children":[
           {"nodeType":"Unit test bundle","name":"B","children":[
             {"nodeType":"Test Suite","name":"S","children":[
               {"nodeType":"Test Case","name":"t()","nodeIdentifier":"S/t()",
                "result":"\#(result)","children":[\#(messages)]}]}]}]}]}
        """#
    }

    /// One flagged chain, two assertion rows: each flagged node with no
    /// flagged children is a tip, independently — the container stays a plain
    /// activity, and both tips hoist to the top level in start order.
    func testEveryTipOfAFlaggedChainHoistsIndependently() throws {
        let testCase = try craftedCase(
            testsJSON: Self.testsDocument(
                result: "Failed",
                failureMessages: ["F.swift:1: boom one", "F.swift:2: boom two"]
            ),
            activitiesJSON: #"""
            {"testIdentifier":"S/t()","testRuns":[{"activities":[
              {"title":"container","isAssociatedWithFailure":true,"startTime":1,
               "childActivities":[
                 {"title":"boom one","isAssociatedWithFailure":true,"startTime":2},
                 {"title":"boom two","isAssociatedWithFailure":true,"startTime":3}]}]}]}
            """#
        )
        let rows = testCase.iterations[0].activities
        XCTAssertEqual(
            rows.map(\.title),
            ["container", "F.swift:1: boom one", "F.swift:2: boom two"]
        )
        XCTAssertEqual(rows.map(\.isFailure), [false, true, true])
        XCTAssertTrue(
            rows[0].subActivities.isEmpty,
            "Both tips must hoist out of the container"
        )
    }

    /// A flagged activity with no flagged descendants is itself the tip: it
    /// keeps its failure flag, gets retitled by the join, and stays where the
    /// interleave puts it.
    func testFlaggedLeafIsItsOwnTip() throws {
        let testCase = try craftedCase(
            testsJSON: Self.testsDocument(
                result: "Failed", failureMessages: ["F.swift:9: solo boom"]
            ),
            activitiesJSON: #"""
            {"testIdentifier":"S/t()","testRuns":[{"activities":[
              {"title":"solo boom","isAssociatedWithFailure":true,"startTime":1}]}]}
            """#
        )
        let rows = testCase.iterations[0].activities
        XCTAssertEqual(rows.map(\.title), ["F.swift:9: solo boom"])
        XCTAssertEqual(rows.map(\.isFailure), [true])
    }

    // MARK: - Fixture pins for the bookkeeping-row rules

    /// The attachment-shadow join's guards are load-bearing: on
    /// `testWithSpecialChars()` the genuine assertion row shares the
    /// attachment's millisecond, and only `leaf`+`non-failure` keep it out of
    /// the shadow rule's mouth. The shadow row itself — titled with the
    /// attachment's user name — must be gone.
    func testSameMillisecondFailureSurvivesTheShadowJoin() throws {
        let specialChars = try XCTUnwrap(
            try testCases(in: read("TestResults"))
                .first { $0.identifier == "FirstSuite/testWithSpecialChars()" }
        )
        let rows = flattened(specialChars.iterations[0].activities)
        XCTAssertFalse(
            rows.contains { $0.title.hasPrefix("FileName with DoubleQuote") },
            "The attachment's shadow row must be dropped"
        )
        XCTAssertTrue(
            rows.contains { $0.isFailure && $0.title.contains("failed on purpose") },
            "The genuine failure row sharing the shadow's millisecond must survive"
        )
        let container = try XCTUnwrap(
            rows.first { $0.title.hasPrefix("Activity with DoubleQuote") }
        )
        XCTAssertFalse(container.attachments.isEmpty, "The attachment itself stays")
    }

    /// Expected failures are non-events in the report, exactly as legacy has
    /// always rendered them: the `XCTExpectFailure` message claims and removes
    /// its matching activity row (exact title match), and nothing is appended.
    func testExpectedFailureRowsAreClaimedAndRemoved() throws {
        let expected = try XCTUnwrap(
            try testCases(in: read("RetryResults"))
                .first { $0.identifier == "RetryTests/testInUnknownState()" }
        )
        let rows = flattened(expected.iterations[0].activities)
        XCTAssertFalse(
            rows.contains { $0.title.contains("Expecting a failure here") },
            "The expected-failure activity row must be claimed and removed"
        )
        XCTAssertFalse(
            rows.contains(where: \.isFailure),
            "No failure row may be appended for an expected failure"
        )
        XCTAssertTrue(
            rows.contains { $0.title == "Tear Down" },
            "Only the expected-failure rows disappear, not the timeline"
        )
    }

    /// Content-addressed export names carry `~` and `=`; the rendered `src`
    /// and `data` attributes must point at files that actually exist next to
    /// the report, or every attachment link in a linking-mode report is dead.
    func testLinkingModeSourcesResolveToExportedFiles() throws {
        let source = try XCTUnwrap(
            Bundle.testBundle.url(forResource: "TestResults", withExtension: "xcresult")
        )
        let copy = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent(source.lastPathComponent)
        try FileManager.default.createDirectory(
            at: copy.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try FileManager.default.copyItem(at: source, to: copy)

        let summary = Summary(
            resultPaths: [copy.path],
            renderingMode: .linking,
            downsizeImagesEnabled: false,
            downsizeScaleFactor: 1,
            backend: .modern
        )
        let html = summary.generatedHtmlReport()

        let pattern = try NSRegularExpression(
            pattern: #"(?:src|data)="(TestResults\.xcresult/[^"]+)""#
        )
        let range = NSRange(html.startIndex..., in: html)
        let sources = pattern.matches(in: html, range: range).compactMap { match in
            Range(match.range(at: 1), in: html).map { String(html[$0]) }
        }
        XCTAssertFalse(sources.isEmpty, "No attachment sources rendered — vacuous")
        XCTAssertTrue(
            sources.contains { $0.contains("~") && $0.contains("=") },
            "Content-addressed names must exercise the URL-hostile characters"
        )
        let outputRoot = copy.deletingLastPathComponent()
        for relative in Set(sources) {
            XCTAssertTrue(
                FileManager.default.fileExists(
                    atPath: outputRoot.appendingPathComponent(relative).path
                ),
                "Rendered source '\(relative)' resolves to no exported file"
            )
        }
    }
}
