//
//  DifferentialTests.swift
//
//  Renders each fixture through both readers and holds the difference to the
//  declared allow-list. This is only possible while xcresulttool supports both
//  formats; it skips itself, loudly, once it does not.
//

import XCTest
@testable import XCTestHTMLReportCore

final class DifferentialTests: XCTestCase {
    private static let fixtures = ["TestResults", "SanityResults", "RetryResults"]

    /// Linking-mode summaries and their normalized renders, one per
    /// fixture-and-backend. Rendering is deterministic for a given backend
    /// (#430), so sharing across test methods compares the same bytes the
    /// other assertions held, and halves a suite dominated by `xcresulttool`
    /// subprocess time.
    private static var summaries: [String: Summary] = [:]
    private static var normalizedRenders: [String: String] = [:]

    private struct AllowList: Decodable {
        struct Loss: Decodable {
            let rule: String
            let field: String
            let effect: String
        }

        let knownLosses: [Loss]
    }

    private func allowList() throws -> AllowList {
        let url = try XCTUnwrap(
            Bundle.testBundle.url(
                forResource: "differential-allowlist", withExtension: "json"
            )
        )
        return try JSONDecoder().decode(AllowList.self, from: Data(contentsOf: url))
    }

    private func summary(_ resource: String, _ backend: ResultBackend) throws -> Summary {
        let key = "\(resource)|\(backend.rawValue)"
        if let cached = Self.summaries[key] {
            return cached
        }
        let url = try XCTUnwrap(
            Bundle.testBundle.url(forResource: resource, withExtension: "xcresult")
        )
        let summary = Summary(
            resultPaths: [url.path],
            renderingMode: .linking,
            downsizeImagesEnabled: false,
            downsizeScaleFactor: 0.5,
            backend: backend
        )
        Self.summaries[key] = summary
        return summary
    }

    /// The identifier-normalized `.linking` render. Only `.linking` renders
    /// are safe to normalize: inline base64 can contain a 32-character hex
    /// run, which the digest pattern would eat.
    private func normalizedRender(
        _ resource: String, _ backend: ResultBackend
    ) throws -> String {
        let key = "\(resource)|\(backend.rawValue)"
        if let cached = Self.normalizedRenders[key] {
            return cached
        }
        let render = try normalizeIdentifiers(
            summary(resource, backend).generatedHtmlReport()
        )
        Self.normalizedRenders[key] = render
        return render
    }

    /// Skips unless *both* backends can actually run, and proves it rather
    /// than assuming it.
    ///
    /// Requesting `.legacy` on a modern-only host must not quietly hand back a
    /// modern reader: the differential would then compare the modern backend
    /// against itself and report parity. `resolve()` returns
    /// `.legacyUnavailable` instead of substituting, and this asserts on that.
    private func requireBothBackends() throws {
        switch ResultBackend.legacy.resolve() {
        case .legacyUnavailable:
            throw XCTSkip(
                "Toolchain has no legacy commands; the differential cannot run. "
                    + "Delete LegacyResultReader and this test together."
            )
        case let .use(backend):
            XCTAssertEqual(
                backend, .legacy,
                "Requested the legacy reader and resolved to \(backend). A "
                    + "substituted backend would make every comparison below "
                    + "a modern-vs-modern tautology."
            )
        }
    }

    /// Counts and statuses must match exactly. These are the assertions that
    /// would catch the multi-repetition status regression.
    func testStatusesAndCountsMatchAcrossBackends() throws {
        try requireBothBackends()
        for fixture in Self.fixtures {
            let legacy = try summary(fixture, .legacy)
            let modern = try summary(fixture, .modern)

            func statuses(_ summary: Summary) -> [String: String] {
                Dictionary(
                    summary.runs.flatMap(\.allTests)
                        .map { ($0.identifier, $0.status.rawValue) },
                    uniquingKeysWith: { first, _ in first }
                )
            }
            XCTAssertEqual(
                statuses(legacy), statuses(modern),
                "\(fixture): identifier→status differs between backends"
            )

            // Assert before zipping: `zip` truncates to the shorter sequence,
            // so a backend that produced fewer runs would compare equal on the
            // ones it did produce and pass.
            XCTAssertEqual(
                legacy.runs.count, modern.runs.count,
                "\(fixture): backends disagree on the number of runs"
            )

            for (legacyRun, modernRun) in zip(legacy.runs, modern.runs) {
                XCTAssertEqual(
                    legacyRun.numberOfTests, modernRun.numberOfTests, "\(fixture): total"
                )
                XCTAssertEqual(
                    legacyRun.numberOfPassedTests, modernRun.numberOfPassedTests,
                    "\(fixture): passed"
                )
                XCTAssertEqual(
                    legacyRun.numberOfFailedTests, modernRun.numberOfFailedTests,
                    "\(fixture): failed"
                )
                XCTAssertEqual(
                    legacyRun.numberOfSkippedTests, modernRun.numberOfSkippedTests,
                    "\(fixture): skipped"
                )
                XCTAssertEqual(
                    legacyRun.numberOfMixedTests, modernRun.numberOfMixedTests,
                    "\(fixture): mixed"
                )
            }
        }
    }

    /// The allow-list and the masker must name exactly the same rules, in both
    /// directions. An entry with no implementation would silently mask
    /// nothing, leaving the difference it claims to cover to fail somewhere
    /// confusing; an implementation with no entry is dead masking code whose
    /// justification nobody reviewed.
    func testEveryAllowListRuleIsImplemented() throws {
        let declared = try Set(allowList().knownLosses.map(\.rule))
        XCTAssertEqual(
            declared, KnownLossMasker.implementedRules,
            "The allow-list and KnownLossMasker.implementedRules disagree. "
                + "Every declared rule needs an implementation and vice versa."
        )
    }

    /// The assertion the whole exercise exists for: mask exactly the declared
    /// losses out of both renders, and require what remains to be identical.
    ///
    /// This is the strong form. Checking only that declared markers appear and
    /// disappear would prove nothing about the lines nobody declared, and an
    /// undeclared regression would sail straight through.
    func testMaskedRendersAreIdenticalAcrossBackends() throws {
        try requireBothBackends()
        let rules = try allowList().knownLosses.map(\.rule)

        for fixture in Self.fixtures {
            let legacySummary = try summary(fixture, .legacy)
            let legacy = try KnownLossMasker.mask(
                normalizedRender(fixture, .legacy), rules: rules
            )
            let modern = try KnownLossMasker.mask(
                normalizedRender(fixture, .modern), rules: rules
            )

            // Non-vacuity: the mask must not have erased the content being
            // compared. Without this, a mask broad enough to delete everything
            // would make the comparison below pass on any two inputs.
            for title in legacySummary.runs.flatMap(\.allTests).map(\.title) {
                XCTAssertTrue(
                    legacy.contains(title),
                    "\(fixture): masking removed test '\(title)' from the "
                        + "comparison. The mask is too broad."
                )
            }

            guard legacy != modern else {
                continue
            }
            let legacyLines = legacy.split(separator: "\n").map(String.init)
            let modernLines = modern.split(separator: "\n").map(String.init)
            let differing = Set(legacyLines).symmetricDifference(Set(modernLines))
            // An empty set with unequal strings means the same lines appear in
            // a different order or multiplicity; report the first divergent
            // position instead, or the failure is unactionable.
            let firstMismatch = zip(legacyLines, modernLines).enumerated()
                .first { $1.0 != $1.1 }
                .map { index, pair in
                    """
                    First sequential mismatch at masked line \(index):
                      legacy: \(pair.0)
                      modern: \(pair.1)
                    context (legacy \(max(0, index - 3))..\(index)):
                    \(legacyLines[max(0, index - 3) ... index].joined(separator: "\n"))
                    """
                } ?? "Line counts: legacy \(legacyLines.count), modern \(modernLines.count)"
            XCTFail(
                """
                \(fixture): \(differing.count) distinct line(s) differ after \
                masking the declared losses. Each is either a parity bug in \
                the modern reader, or an undeclared format loss that needs an \
                allow-list entry with a written justification. First 20:
                \(differing.sorted().prefix(20).joined(separator: "\n"))
                \(firstMismatch)
                """
            )
        }
    }

    /// Every allow-list entry must still be *necessary* somewhere: for each
    /// fixture, each rule is left out in turn, and a rule fires when its
    /// absence leaves the two renders unequal. An entry that fires on no
    /// fixture is masking a divergence that no longer exists — Apple filled
    /// the gap, or the fixture stopped exercising it — and must be deleted,
    /// not left to rot as a place where a real regression could hide.
    func testEveryAllowListEntryStillMasksARealDivergence() throws {
        try requireBothBackends()
        let rules = try allowList().knownLosses.map(\.rule)

        var firedAnywhere: Set<String> = []
        for fixture in Self.fixtures {
            let fired = try KnownLossMasker.firedRules(
                legacy: normalizedRender(fixture, .legacy),
                modern: normalizedRender(fixture, .modern),
                rules: rules
            )
            print("Differential allow-list rules fired on \(fixture): \(fired.sorted())")
            firedAnywhere.formUnion(fired)
        }

        for rule in rules where !firedAnywhere.contains(rule) {
            XCTFail(
                "Allow-list rule '\(rule)' masked nothing on any fixture. The "
                    + "divergence it declares no longer exists; delete the "
                    + "entry (and its masker rule) rather than letting it rot."
            )
        }
    }

    /// Restores the coverage the `durations` mask gives up.
    ///
    /// That rule normalises every `(1.23s)` in the report, because the
    /// divergent ones cannot be scoped by line. This asserts directly on the
    /// model that the durations which *should* agree do — XCTest test cases,
    /// as against groups and Swift Testing cases, which the format leaves null
    /// on modern.
    func testXCTestCaseDurationsAgreeAcrossBackends() throws {
        try requireBothBackends()
        for fixture in Self.fixtures {
            let legacy = try summary(fixture, .legacy)
            let modern = try summary(fixture, .modern)

            func durations(_ summary: Summary) -> [String: TimeInterval] {
                Dictionary(
                    summary.runs.flatMap(\.allTests)
                        // Swift Testing cases report no duration on modern.
                        .filter { !$0.identifier.hasPrefix("SwiftTestingSuite/") }
                        .map { ($0.identifier, $0.duration) },
                    uniquingKeysWith: { first, _ in first }
                )
            }
            let legacyDurations = durations(legacy)
            XCTAssertFalse(
                legacyDurations.isEmpty,
                "\(fixture): no XCTest cases to compare — assertion would be vacuous"
            )
            for (identifier, legacyValue) in legacyDurations {
                let modernValue = try XCTUnwrap(durations(modern)[identifier])
                XCTAssertEqual(
                    legacyValue, modernValue, accuracy: 0.0005,
                    "\(fixture): \(identifier) duration differs between backends"
                )
            }
        }
    }

    /// The summary header's two derived numbers, on the model rather than
    /// through the render — the same reason
    /// `testXCTestCaseDurationsAgreeAcrossBackends` exists.
    ///
    /// The duration sits one regex away from the `durations` mask, which
    /// normalises the parenthesised `(1.23s)` form the tree uses: a header
    /// that ever adopted that form would have its divergence masked away
    /// silently. It sums *leaf* tests, which agree. Groups do not and cannot
    /// — `durationInSeconds` is null on every suite node in the modern
    /// format, which is exactly what that allow-list entry declares.
    func testSummaryHeaderNumbersAgreeAcrossBackends() throws {
        try requireBothBackends()
        for fixture in Self.fixtures {
            let legacy = try summary(fixture, .legacy)
            let modern = try summary(fixture, .modern)

            let legacyHeader = RunSummary(runs: legacy.runs)
            let modernHeader = RunSummary(runs: modern.runs)

            XCTAssertGreaterThan(
                legacyHeader.duration, 0,
                "\(fixture): a zero total would make the comparison vacuous"
            )
            XCTAssertEqual(
                legacyHeader.duration, modernHeader.duration, accuracy: 0.0005,
                "\(fixture): the header's run duration differs between backends"
            )

            // Rendered, not field by field: it is the two-decimal string that
            // reaches the page, and it is the string the differential holds.
            XCTAssertEqual(
                legacyHeader.duration.formattedSeconds,
                modernHeader.duration.formattedSeconds,
                "\(fixture): the header's rendered duration differs between backends"
            )

            XCTAssertEqual(
                legacyHeader.tally.buckets.map { "\($0.label) \($0.count)" },
                modernHeader.tally.buckets.map { "\($0.label) \($0.count)" },
                "\(fixture): the header's status buckets differ between backends"
            )
            XCTAssertEqual(
                legacyHeader.tally.total, legacy.runs.flatMap(\.allTests).count,
                "\(fixture): the buckets must account for every test"
            )
        }
    }

    func testAttachmentPayloadsAreByteIdenticalAcrossBackends() throws {
        try requireBothBackends()

        /// Keyed by filename and counted, not collected into a Set: a Set
        /// collapses duplicates, so a backend that dropped one of two identical
        /// screen recordings would still compare equal.
        func payloads(_ summary: Summary) -> [String: [Data]] {
            var byName: [String: [Data]] = [:]
            for attachment in summary.allAttachments {
                guard case let .data(data) = attachment.content else {
                    continue
                }
                byName[attachment.filename, default: []].append(data)
            }
            return byName.mapValues { $0.sorted { $0.count < $1.count } }
        }

        for fixture in Self.fixtures {
            // Rendered inline so the bytes are in hand rather than on disk.
            let legacy = try summaryInline(fixture, .legacy)
            let modern = try summaryInline(fixture, .modern)
            let legacyPayloads = payloads(legacy)
            XCTAssertFalse(
                legacyPayloads.isEmpty,
                "\(fixture): no attachment bytes to compare — the assertion "
                    + "below would pass vacuously"
            )
            XCTAssertEqual(
                legacyPayloads.mapValues(\.count),
                payloads(modern).mapValues(\.count),
                "\(fixture): attachment counts differ between backends"
            )
            XCTAssertEqual(
                legacyPayloads, payloads(modern),
                "\(fixture): attachment bytes differ between backends"
            )
        }
    }

    private func summaryInline(_ resource: String, _ backend: ResultBackend) throws -> Summary {
        let url = try XCTUnwrap(
            Bundle.testBundle.url(forResource: resource, withExtension: "xcresult")
        )
        return Summary(
            resultPaths: [url.path],
            renderingMode: .inline,
            downsizeImagesEnabled: false,
            downsizeScaleFactor: 0.5,
            backend: backend
        )
    }
}
