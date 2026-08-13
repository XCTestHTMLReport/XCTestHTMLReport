//
//  ModernResultReaderTests.swift
//

import XCTest
@testable import XCTestHTMLReportCore

final class ModernResultReaderTests: XCTestCase {
    // MARK: - Helpers

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

    // MARK: - Tree, status, iterations

    func testRepetitionsBecomeIterationsAndParentResultIsIgnored() throws {
        let retried = try XCTUnwrap(
            try testCases(in: read("RetryResults"))
                .first { $0.identifier == "RetryTests/testRetryOnFailure()" }
        )
        // The Test Case node says "Passed". Legacy reports mixed. Taking the
        // parent result here would silently turn a mixed test green.
        XCTAssertEqual(retried.iterations.count, 2)
        XCTAssertEqual(retried.iterations.map(\.iterationNumber), [1, 2])
        XCTAssertEqual(retried.iterations.map(\.status), [.failed, .passed])
    }

    func testStatusesMapIntoTheNeutralEnum() throws {
        let cases = try testCases(in: read("TestResults"))
        func status(_ identifier: String) throws -> ParsedStatus {
            try XCTUnwrap(cases.first { $0.identifier == identifier })
                .iterations[0].status
        }
        XCTAssertEqual(try status("FirstSuite/testOne()"), .passed)
        XCTAssertEqual(try status("FirstSuite/testTwo()"), .failed)
        XCTAssertEqual(try status("SampleAppUnitTests/testSkipped()"), .skipped)

        // Both readers must agree on the vocabulary, which is the whole point
        // of the enum: no fixture assertion can catch one reader drifting.
        XCTAssertEqual(ModernResultReader.status("Passed"), LegacyResultReader.status("Success"))
        XCTAssertEqual(ModernResultReader.status("Failed"), LegacyResultReader.status("Failure"))
        XCTAssertEqual(ModernResultReader.status("Skipped"), LegacyResultReader.status("Skipped"))
        XCTAssertEqual(
            ModernResultReader.status("Expected Failure"),
            LegacyResultReader.status("Expected Failure")
        )
        // `unknown` is in the published schema but in no fixture.
        XCTAssertEqual(ModernResultReader.status("unknown"), .unknown)
        XCTAssertEqual(ModernResultReader.status(nil), .unknown)
    }

    /// Replaces `testExpectedFailureStillRendersAsUnknown`, which pinned the
    /// flattening this test now pins the removal of.
    ///
    /// That pin was correct while the port was the only thing in flight: the
    /// model named the state, the renderer folded it into `.unknown`, and
    /// holding the renderer still was how the differential stayed meaningful.
    /// #439 is the change that pin was waiting for — an expected failure has
    /// a `Status` of its own so the stylesheet can draw it a glyph, instead
    /// of the empty class that rendered a blank status cell.
    ///
    /// What deliberately did *not* change is where the state comes from: both
    /// readers already mapped xcresult's `Expected Failure`, so this is a
    /// rendering change and neither backend moved. (The fixture's name is a
    /// misnomer inherited from before anyone checked — `testInUnknownState`
    /// is an `XCTExpectFailure`, and is the row the audit reported as an
    /// unknown-status blank.)
    func testExpectedFailureCarriesItsOwnStatus() throws {
        let expectedFailure = try XCTUnwrap(
            try testCases(in: read("RetryResults"))
                .first { $0.identifier == "RetryTests/testInUnknownState()" }
        )
        XCTAssertEqual(expectedFailure.iterations[0].status, .expectedFailure)
        XCTAssertEqual(Status(rawValue: "Expected Failure"), Status.expectedFailure)
        XCTAssertEqual(
            Status(.expectedFailure).cssClass, "expected-failure",
            "The class the stylesheet hangs the expected-failure glyph on"
        )
        XCTAssertNotEqual(
            Status(.expectedFailure), Status(.unknown),
            "Folding these together is what produced the blank cell"
        )
    }

    func testParameterizedTestCarriesItsArguments() throws {
        // Requires the parameterized @Test in SwiftTestingSuite. Without that
        // fixture, `arguments` would be a field no fixture ever populates,
        // asserted by no test.
        let parameterized = try XCTUnwrap(
            try testCases(in: read("TestResults"))
                .first { $0.identifier.contains("parameterizedAddition") },
            "No parameterized test in the fixture — see Task 8 of the migration plan"
        )
        XCTAssertEqual(
            parameterized.arguments.sorted(), ["1", "2", "3"],
            "Arguments nodes exist in the bundle but did not reach the model"
        )
    }

    func testTreeIsFlatWithoutLegacyWrapperGroups() throws {
        let result = try read("TestResults")
        let targets = result.runs.flatMap(\.testables).map(\.targetName).sorted()
        XCTAssertEqual(targets, ["SampleAppUITests", "SampleAppUnitTests"])

        let groupNames = result.runs
            .flatMap(\.testables)
            .flatMap(\.groups)
            .map(\.name)
        // Deliberately flat: no "Selected tests" / "All tests" / "*.xctest".
        XCTAssertFalse(groupNames.contains("Selected tests"))
        XCTAssertFalse(groupNames.contains("All tests"))
        XCTAssertTrue(groupNames.contains("FirstSuite"))
        XCTAssertTrue(groupNames.contains("SwiftTestingSuite"))
    }

    // MARK: - Failure text: file:line from the tests document

    /// The activities document reports each assertion failure as an activity
    /// row but drops the `file:line` prefix; the tests document's `Failure
    /// Message` node keeps it. The reader joins the two — message text onto
    /// the activity row's position — so losing either half is a regression.
    func testFailureTitlesKeepFileAndLineFromTheTestsDocument() throws {
        let failing = try XCTUnwrap(
            try testCases(in: read("TestResults"))
                .first { $0.identifier == "FirstSuite/testTwo()" }
        )
        let rows = flattened(failing.iterations[0].activities)
            .filter { $0.title.hasSuffix("XCTAssertTrue failed - Test failed") }

        XCTAssertEqual(
            rows.count, 1,
            "The same failure must not render as both the activity row and an appended message row"
        )
        let row = try XCTUnwrap(rows.first)
        XCTAssertTrue(
            row.title.hasPrefix("FirstSuite.swift:"),
            "Failure text must come from the Failure Message node, which keeps file:line — got '\(row.title)'"
        )
        XCTAssertTrue(row.isFailure)
        XCTAssertNotNil(
            row.start,
            "The retitled row keeps the activity's own timestamp and position"
        )
    }

    /// The retried test's assertion fires inside the user's own activity, so
    /// the activities document nests the failure row. The join retitles it,
    /// and the hoist then moves it to the top level — positioned by its own
    /// timestamp through the shared interleave — because the legacy format
    /// cannot nest failure rows and re-nesting legacy's by time window was
    /// tested and rejected (windows collide at millisecond granularity).
    func testNestedRetryFailureIsRetitledAndHoisted() throws {
        let retried = try XCTUnwrap(
            try testCases(in: read("RetryResults"))
                .first { $0.identifier == "RetryTests/testRetryOnFailure()" }
        )
        let firstAttempt = retried.iterations[0]
        let wrapper = try XCTUnwrap(
            firstAttempt.activities.first { $0.title == "Retryable Activity" },
            "The user-created activity must survive translation"
        )
        XCTAssertFalse(
            wrapper.isFailure,
            "The container is not the assertion row; only the tip of the flagged chain is"
        )
        XCTAssertTrue(
            flattened(wrapper.subActivities).isEmpty,
            "The failure row must be hoisted out of the activity it fired in"
        )

        let hoisted = try XCTUnwrap(
            firstAttempt.activities.first(where: \.isFailure),
            "The hoisted failure row surfaces at the top level"
        )
        XCTAssertTrue(
            hoisted.title.hasPrefix("RetryTests.swift:"),
            "Hoisted failure rows are retitled from the Failure Message node too — got '\(hoisted.title)'"
        )
        XCTAssertNotNil(
            hoisted.start,
            "The hoisted row keeps its own timestamp; the shared interleave positions it"
        )
        // Positioned where it occurred: the assertion fired during the
        // user-created activity, so start-keyed interleaving puts the row
        // right after it, not at the end of the test.
        let titles = firstAttempt.activities.map(\.title)
        let wrapperIndex = try XCTUnwrap(titles.firstIndex(of: "Retryable Activity"))
        let failureIndex = try XCTUnwrap(titles
            .firstIndex(where: { $0.hasPrefix("RetryTests.swift:") }))
        XCTAssertEqual(
            failureIndex, wrapperIndex + 1,
            "Start-keyed interleave places the failure beside the activity it fired in"
        )
        // And nothing appended a second copy anywhere.
        XCTAssertEqual(
            flattened(firstAttempt.activities).filter { $0.title.hasSuffix(": failed") }.count,
            1
        )
    }

    /// Failure Messages with no matching activity row — skip reasons and
    /// expected-failure notes, whose activity rows are not failure-flagged —
    /// still append, or the reason never reaches the report at all.
    func testSkipReasonAppendsWhenNoActivityRowMatches() throws {
        let skipped = try XCTUnwrap(
            try testCases(in: read("TestResults"))
                .first { $0.identifier == "SampleAppUnitTests/testSkipped()" }
        )
        XCTAssertTrue(
            skipped.iterations[0].activities
                .contains { $0.isFailure && $0.title.contains("Test skipped") },
            "The skip reason rides a Failure Message node with no activity twin"
        )
    }

    // MARK: - Fault discipline

    /// A failed activities query degrades to an empty activity list. That is
    /// only acceptable because it is *reported*: without the fault the CLI
    /// exits 0 on a report whose tests have no activities at all.
    func testFailedActivitiesQueryRecordsAFault() throws {
        let url = try XCTUnwrap(
            Bundle.testBundle.url(forResource: "SanityResults", withExtension: "xcresult")
        )

        // Passes everything through to the real tool except `activities`,
        // which always fails.
        struct ActivitiesFailingClient: XCResultToolInvoking {
            let wrapped: XCResultToolClient

            var bundleDescription: String {
                wrapped.bundleDescription
            }

            func run(_ arguments: [String]) throws -> Data {
                try wrapped.run(arguments)
            }

            func json<T: Decodable>(_ arguments: [String], as type: T.Type) throws -> T {
                if arguments.contains("activities") {
                    throw XCResultToolError.executionFailed(
                        arguments: arguments, status: 1, stderr: "injected failure"
                    )
                }
                return try wrapped.json(arguments, as: type)
            }
        }

        let collector = FaultCollector()
        let reader = ModernResultReader(
            client: ActivitiesFailingClient(wrapped: XCResultToolClient(bundleURL: url)),
            payloadStore: nil,
            faultCollector: collector
        )
        let result = try XCTUnwrap(reader.read())

        // The read still succeeds — degraded, not aborted.
        XCTAssertFalse(testCases(in: result).isEmpty)
        XCTAssertTrue(
            collector.faults.contains { $0.kind == .missingActivities },
            "A failed activities query must be reported, not swallowed"
        )
    }

    /// A decodable document with no destinations is a failed read, not an
    /// empty report: nil routes it to `.missingInvocationRecord` and exit 3,
    /// exactly like the legacy reader's no-runs case.
    func testEmptyButDecodableDocumentReadsAsNil() throws {
        struct EmptyDocumentClient: XCResultToolInvoking {
            var bundleDescription: String {
                "Empty.xcresult"
            }

            func run(_: [String]) throws -> Data {
                Data("{\"devices\":[],\"testNodes\":[]}".utf8)
            }

            func json<T: Decodable>(_ arguments: [String], as type: T.Type) throws -> T {
                try JSONDecoder().decode(type, from: run(arguments))
            }
        }

        let reader = ModernResultReader(
            client: EmptyDocumentClient(),
            payloadStore: nil,
            faultCollector: FaultCollector()
        )
        XCTAssertNil(reader.read())
    }

    /// The trap the spec names: fields the modern backend structurally cannot
    /// provide — attachment display names, activity types, suite durations,
    /// finish times — must never fault. A full modern-path render of every
    /// fixture, attachments and logs included, has to come out clean, or
    /// every modern run exits 3.
    func testModernRenderOfEveryFixtureRecordsNoFaults() throws {
        for resource in ["TestResults", "SanityResults", "RetryResults"] {
            let source = try XCTUnwrap(
                Bundle.testBundle.url(forResource: resource, withExtension: "xcresult")
            )
            // Copy: rendering in linking mode writes payloads and logs into
            // the bundle directory.
            let copy = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent(UUID().uuidString)
                .appendingPathComponent(source.lastPathComponent)
            try FileManager.default.createDirectory(
                at: copy.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try FileManager.default.copyItem(at: source, to: copy)

            let collector = FaultCollector()
            let client = XCResultToolClient(bundleURL: copy)
            let store = ModernPayloadStore(
                client: client, bundleURL: copy, faultCollector: collector
            )
            let reader = ModernResultReader(
                client: client, payloadStore: store, faultCollector: collector
            )
            let parsed = try XCTUnwrap(reader.read(), "\(resource) must read")

            let runs = parsed.runs.enumerated().compactMap { index, run in
                Run(
                    run: run,
                    identifierPath: IdentifierPath.root
                        .appending("bundle0")
                        .appending("action\(index)"),
                    file: store,
                    renderingMode: .linking,
                    downsizeImagesEnabled: false,
                    downsizeScaleFactor: 1
                )
            }
            XCTAssertFalse(runs.isEmpty, "\(resource) must render at least one run")

            let unresolved = runs.flatMap(\.allAttachments).filter(\.failedToResolve)
            XCTAssertTrue(
                unresolved.isEmpty,
                "\(resource): attachments failed to resolve on the modern path: "
                    + unresolved.map(\.faultDescription).joined(separator: ", ")
            )
            XCTAssertTrue(
                collector.faults.isEmpty,
                "\(resource): modern render must be fault-free, got \(collector.faults)"
            )
        }
    }
}
