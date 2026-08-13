//
//  JsonReportTests.swift
//
//  Holds `--json` to its wire contract (docs/json-schema.md): our own schema,
//  not the legacy object graph, and identical across backends up to exactly
//  the two permitted value-difference classes — the four declared
//  render-level losses (class 1) and the modern-only `arguments` capability
//  (class 2). Every mask applied here carries a non-vacuity guard, so a
//  divergence that stops existing fails the test rather than rotting as dead
//  masking.
//

import XCTest
@testable import XCTestHTMLReportCore

final class JsonReportTests: XCTestCase {
    // MARK: - Shared documents

    private static let fixtures = ["TestResults", "SanityResults", "RetryResults"]

    /// One parse per fixture-and-backend. Building a `Summary` spawns
    /// `xcresulttool` subprocesses, so tests share documents the same way
    /// `DifferentialTests` shares renders.
    private static var documents: [String: [String: Any]] = [:]

    private func document(
        _ resource: String, _ backend: ResultBackend
    ) throws -> [String: Any] {
        let key = "\(resource)|\(backend.rawValue)"
        if let cached = Self.documents[key] {
            return cached
        }
        let url = try XCTUnwrap(
            Bundle.testBundle.url(forResource: resource, withExtension: "xcresult")
        )
        let text = Summary(
            resultPaths: [url.path],
            renderingMode: .linking,
            downsizeImagesEnabled: false,
            downsizeScaleFactor: 0.5,
            backend: backend
        ).generatedJsonReport()
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any],
            "--json output is not a single JSON object"
        )
        Self.documents[key] = object
        return object
    }

    /// Mirrors `DifferentialTests.requireBothBackends`: skip when the
    /// toolchain has no legacy commands, and refuse a silently substituted
    /// backend, which would compare modern against itself.
    private func requireBothBackends() throws {
        switch ResultBackend.legacy.resolve() {
        case .legacyUnavailable:
            throw XCTSkip(
                "Toolchain has no legacy commands; the cross-backend "
                    + "comparison cannot run."
            )
        case let .use(backend):
            XCTAssertEqual(backend, .legacy)
        }
    }

    // MARK: - The schema is ours

    func testEmitsOurSchemaNotTheLegacyObjectGraph() throws {
        let object = try document("SanityResults", .fromEnvironment())
        XCTAssertNotNil(object["runs"])
        XCTAssertEqual(object["schemaVersion"] as? String, "1.0.0")
        XCTAssertEqual(
            Set(object.keys), ["schemaVersion", "runs"],
            "The top level carries exactly the two documented keys"
        )
        // The legacy dump wrapped every scalar in {"_value": ...}. Ours does not.
        XCTAssertFalse(
            String(describing: object).contains("_value"),
            "Output still looks like the legacy object graph"
        )
    }

    /// Contract pins that need no second backend: enum spellings are the five
    /// documented lowercase strings, timestamps are ISO-8601 UTC with
    /// millisecond precision, and both are asserted against real data rather
    /// than against the encoder's own constants.
    func testStatusAndTimestampEncodingsMatchTheContract() throws {
        let object = try document("TestResults", .fromEnvironment())

        let statuses = Set(
            testCases(in: object)
                .flatMap { $0["iterations"] as? [[String: Any]] ?? [] }
                .compactMap { $0["status"] as? String }
        )
        XCTAssertFalse(statuses.isEmpty, "No statuses found — vacuous")
        XCTAssertTrue(
            statuses.isSubset(of: ["passed", "failed", "skipped", "expectedFailure", "unknown"]),
            "Undocumented status spelling: \(statuses)"
        )
        XCTAssertTrue(
            statuses.isSuperset(of: ["passed", "failed", "skipped"]),
            "TestResults exercises at least these three: \(statuses)"
        )

        let timestampShape = try NSRegularExpression(
            pattern: #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$"#
        )
        let starts = activityRows(in: object).compactMap { $0["start"] as? String }
        XCTAssertFalse(starts.isEmpty, "No timestamps found — vacuous")
        for start in starts {
            XCTAssertNotNil(
                timestampShape.firstMatch(
                    in: start, range: NSRange(start.startIndex..., in: start)
                ),
                "Timestamp '\(start)' is not ISO-8601 UTC with milliseconds"
            )
        }
    }

    // MARK: - Schema identity across backends

    /// Schema identity, not value identity — the spec permits four value
    /// differences and forbids the rest. The schema is recursive (a node is
    /// a group or a test case, at any depth), and the `wrapperGroups` loss
    /// means legacy alone places group nodes at nested positions — so raw
    /// key-path sets differ on every fixture for that permitted reason.
    /// Collapsing the tree's recursion edges (`groups`/`children` become one
    /// segment, consecutive `subActivities` collapse) compares the keys each
    /// *node type* carries instead of the positions nodes happen to occupy:
    /// a key that exists on one backend's groups or test cases and not the
    /// other's still fails, wherever it sits.
    func testSchemaIsIdenticalAcrossBackends() throws {
        try requireBothBackends()

        func keyPaths(_ any: Any, prefix: String = "") -> Set<String> {
            switch any {
            case let dict as [String: Any]:
                return dict.reduce(into: Set<String>()) { acc, pair in
                    acc.insert(collapsed(prefix + pair.key))
                    acc.formUnion(keyPaths(pair.value, prefix: prefix + pair.key + "."))
                }
            case let array as [Any]:
                return array.reduce(into: Set<String>()) { acc, element in
                    acc.formUnion(keyPaths(element, prefix: prefix))
                }
            default:
                return []
            }
        }

        for fixture in Self.fixtures {
            let legacy = try document(fixture, .legacy)
            let modern = try document(fixture, .modern)
            XCTAssertEqual(
                keyPaths(legacy), keyPaths(modern),
                "\(fixture): a key exists on one backend and not the other"
            )
            XCTAssertEqual(
                legacy["schemaVersion"] as? String,
                modern["schemaVersion"] as? String,
                "\(fixture): backends disagree on schemaVersion"
            )
        }
    }

    /// `groups` and `children` unify into one `nodes` segment and repeats
    /// collapse (segment-wise, so a path *ending* in a repeat collapses
    /// too); likewise consecutive `subActivities`. Recursion depth and node
    /// position stop registering; key differences never do.
    private func collapsed(_ path: String) -> String {
        var segments: [String] = []
        for raw in path.split(separator: ".").map(String.init) {
            let segment = raw == "groups" || raw == "children" ? "nodes" : raw
            if segment == segments.last,
               segment == "nodes" || segment == "subActivities"
            {
                continue
            }
            segments.append(segment)
        }
        return segments.joined(separator: ".")
    }

    // MARK: - Class 2: arguments compare by capability, never blind equality

    /// The parameterized fixture exists precisely so this cannot pass
    /// vacuously: legacy must be `[]` because its format has no counterpart,
    /// and modern must be non-empty for the parameterized case because the
    /// bundle really carries the Arguments nodes.
    func testArgumentsAreEmptyOnLegacyAndPopulatedOnModern() throws {
        try requireBothBackends()

        let legacyCases = try testCases(in: document("TestResults", .legacy))
        XCTAssertFalse(legacyCases.isEmpty, "No test cases parsed — vacuous")
        for testCase in legacyCases {
            XCTAssertEqual(
                testCase["arguments"] as? [String], [],
                "Legacy has no Arguments source; \(testCase["identifier"] ?? "?") "
                    + "must be []"
            )
        }

        let modernCases = try testCases(in: document("TestResults", .modern))
        let parameterized = try XCTUnwrap(
            modernCases.first {
                $0["identifier"] as? String
                    == "SwiftTestingSuite/parameterizedAddition(value:)"
            },
            "The parameterized fixture case is missing from the modern document"
        )
        XCTAssertEqual(
            (parameterized["arguments"] as? [String])?.sorted(), ["1", "2", "3"],
            "Modern must surface the @Test(arguments:) values"
        )
        for testCase in modernCases
            where testCase["identifier"] as? String
            != "SwiftTestingSuite/parameterizedAddition(value:)"
        {
            XCTAssertEqual(
                testCase["arguments"] as? [String], [],
                "Non-parameterized case \(testCase["identifier"] ?? "?") "
                    + "must have no arguments"
            )
        }
    }

    // MARK: - The differential: values equal outside the two classes

    /// Mask exactly the declared losses out of both documents, then require
    /// deep equality. Any value difference outside the two permitted classes
    /// is a reader bug, not a permitted variance (the spec's words), and this
    /// is the assertion that catches it.
    func testValueDifferencesAreConfinedToTheTwoPermittedClasses() throws {
        try requireBothBackends()

        for fixture in Self.fixtures {
            var stats = JsonClassMask.Stats()
            let legacy = try JsonClassMask.masked(
                document(fixture, .legacy), legacy: true, stats: &stats
            )
            let modern = try JsonClassMask.masked(
                document(fixture, .modern), legacy: false, stats: &stats
            )

            // Non-vacuity: each class-1 mask must have had something to mask
            // on the fixtures that exercise it, and the class-2 blanking is
            // pinned by testArgumentsAreEmptyOnLegacyAndPopulatedOnModern.
            XCTAssertGreaterThan(
                stats.unwrappedWrapperGroups, 0,
                "\(fixture): no wrapper group unwrapped — the wrapperGroups "
                    + "divergence no longer exists; delete the mask"
            )
            XCTAssertEqual(
                stats.modernAttachmentNames, 0,
                "\(fixture): a modern attachment carried a user-supplied name — "
                    + "the attachmentDisplayNames loss no longer exists"
            )

            let legacyText = JsonClassMask.canonical(legacy)
            let modernText = JsonClassMask.canonical(modern)
            guard legacyText != modernText else {
                continue
            }
            let legacyLines = legacyText.split(separator: "\n").map(String.init)
            let modernLines = modernText.split(separator: "\n").map(String.init)
            let index = zip(legacyLines, modernLines).prefix { $0 == $1 }.count
            let firstMismatch: String
            if index < min(legacyLines.count, modernLines.count) {
                firstMismatch = """
                First mismatch at canonical line \(index):
                  legacy: \(legacyLines[index])
                  modern: \(modernLines[index])
                context (legacy \(max(0, index - 5))..\(index)):
                \(legacyLines[max(0, index - 5) ... index].joined(separator: "\n"))
                """
            } else {
                firstMismatch =
                    "Line counts: legacy \(legacyLines.count), modern \(modernLines.count)"
            }
            XCTFail(
                """
                \(fixture): --json values differ outside the two permitted \
                classes.
                \(firstMismatch)
                """
            )
        }
    }

    // MARK: - JSON walking helpers

    /// Every `kind == "testCase"` object, recursively.
    private func testCases(in any: Any) -> [[String: Any]] {
        switch any {
        case let dict as [String: Any]:
            if dict["kind"] as? String == "testCase" {
                return [dict]
            }
            return dict.values.flatMap(testCases(in:))
        case let array as [Any]:
            return array.flatMap(testCases(in:))
        default:
            return []
        }
    }

    /// Every activity row, recursively — any object carrying `isFailure`.
    private func activityRows(in any: Any) -> [[String: Any]] {
        switch any {
        case let dict as [String: Any]:
            let selfRow: [[String: Any]] = dict["isFailure"] != nil ? [dict] : []
            return selfRow + dict.values.flatMap(activityRows(in:))
        case let array as [Any]:
            return array.flatMap(activityRows(in:))
        default:
            return []
        }
    }
}
