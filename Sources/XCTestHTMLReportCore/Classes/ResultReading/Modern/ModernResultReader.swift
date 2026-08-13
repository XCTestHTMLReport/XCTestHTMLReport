//
//  ModernResultReader.swift
//  XCTestHTMLReportCore
//
//  Builds ParsedResult from `xcresulttool get test-results`.
//
//  The new tree omits the two wrapper levels legacy interposes
//  ("Selected tests" / "All tests", then "<target>.xctest"). We render the
//  natural flat tree rather than synthesising them: whether the wrapper is
//  "Selected tests" or "All tests" depends on run filtering, which the new
//  format does not expose, so one of the two labels would always be invented.
//

import Foundation

struct ModernResultReader: ResultReader {
    // MARK: Internal

    let client: XCResultToolInvoking
    let payloadStore: ModernPayloadStore?
    /// The collector `Summary.init` owns, so a fault recorded here reaches
    /// `summary.faults` and drives the CLI's exit-3 degradation path.
    let faultCollector: FaultCollector

    /// Modern vocabulary into the neutral enum — the mirror of
    /// `LegacyResultReader.status`. Neither reader emits the other's
    /// spelling; that was the point of the design spec's answer 5.
    ///
    /// The full `TestResult` enum is `Passed`, `Failed`, `Skipped`,
    /// `Expected Failure`, `unknown`, taken from
    /// `xcresulttool get test-results tests --schema`. No fixture produces
    /// `unknown`, so it is handled from the published schema rather than from
    /// observed data.
    static func status(_ result: String?) -> ParsedStatus {
        switch result {
        case "Passed": return .passed
        case "Failed": return .failed
        case "Skipped": return .skipped
        case "Expected Failure": return .expectedFailure
        default: return .unknown
        }
    }

    /// Swift Testing `@Test(arguments:)` values.
    ///
    /// `Arguments` is one of the documented `TestNodeType` values, and since
    /// the sample app gained a parameterized `@Test` it is also exercised by
    /// the `TestResults` fixture: one child node per argument set, whose
    /// `name` is the argument's value.
    static func arguments(of node: TestNode) -> [String] {
        (node.children ?? [])
            .filter { $0.nodeType == "Arguments" }
            .compactMap(\.name)
    }

    func read() -> ParsedResult? {
        do {
            let tests = try client.json(
                ["get", "test-results", "tests"], as: TestResultsTests.self
            )

            // A decodable document that yields no destinations is a failed
            // read, not an empty result. Returning `ParsedResult(runs: [])`
            // here would satisfy `Summary.init`'s `guard let`, record no
            // fault, and let `--lenient` write an empty report and exit 0 —
            // where legacy's equivalent failure records
            // `.missingInvocationRecord` and reaches exit 3. Returning nil
            // routes it to the same fault.
            //
            // The general rule, which every reader follows: a structurally
            // empty but successfully decoded read is a failure. Decoding
            // succeeding is not evidence that the bundle had content.
            let devices = tests.devices ?? []
            guard !devices.isEmpty else {
                Logger.warning("No destinations reported for \(client.bundleDescription)")
                return nil
            }

            // One run per destination, matching legacy's one-run-per-ActionRecord.
            return ParsedResult(runs: devices.map { device in
                ParsedRun(
                    destination: ParsedDestination(
                        displayName: device.deviceName ?? "",
                        deviceIdentifier: device.deviceId ?? "",
                        modelName: device.modelName ?? "",
                        operatingSystemVersion: device.osVersion ?? ""
                    ),
                    // The action log has no reference id in the new format;
                    // the payload store forwards this to `get log --type`.
                    logReference: "action",
                    testables: testables(on: device, from: tests)
                )
            })
        } catch {
            Logger.warning("Modern reader failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: Private

    private static let bundleNodeTypes: Set<String> = [
        "UI test bundle", "Unit test bundle",
    ]

    /// The test tree as it ran on one destination.
    ///
    /// With a single destination — every fixture in this suite — this is the
    /// whole tree. With several, the tree must be filtered to the device,
    /// because `ParsedRun` is per-destination and duplicating the full tree
    /// under each run doubles every header total.
    ///
    /// `Device` is itself a `TestNodeType`, so a multi-destination document
    /// nests device nodes inside the tree. **Verify the shape against a real
    /// two-destination bundle before implementing this** — no fixture here
    /// produces one, and the single-destination case (no `Device` nodes,
    /// return the tree as-is) is the only shape confirmed on Xcode 26.2.
    private func testables(
        on _: TestResultsDevice,
        from tests: TestResultsTests
    ) -> [ParsedTestable] {
        (tests.testNodes ?? [])
            .flatMap { $0.children ?? [] }
            .filter { Self.bundleNodeTypes.contains($0.nodeType ?? "") }
            .map { bundle in
                ParsedTestable(
                    targetName: bundle.name ?? "",
                    groups: (bundle.children ?? []).map(parseGroup)
                )
            }
    }

    private func parseGroup(_ node: TestNode) -> ParsedGroup {
        let children: [ParsedNode] = (node.children ?? []).compactMap { child in
            switch child.nodeType {
            case "Test Case": return .testCase(parseTestCase(child))
            case "Test Suite": return .group(parseGroup(child))
            default: return nil
            }
        }
        return ParsedGroup(
            name: node.name ?? "---group-name-not-found---",
            identifier: node.nodeIdentifier ?? node.name ?? "---group-identifier-not-found---",
            // `durationInSeconds` is null on every Test Suite, Test Plan and
            // *test bundle node in all three fixtures, so this is always 0 for
            // groups while legacy reports a real value. Not a bug to fix here —
            // the format does not carry it — but it is why `durations` is an
            // allow-list entry. Do not synthesise a sum of children: that would
            // be a fabricated number, and it would make the two backends agree
            // by inventing data rather than by sharing it.
            duration: node.durationInSeconds ?? 0,
            children: children
        )
    }

    private func parseTestCase(_ node: TestNode) -> ParsedTestCase {
        let repetitions = (node.children ?? []).filter { $0.nodeType == "Repetition" }
        let identifier = node.nodeIdentifier ?? ""

        let iterations: [ParsedIteration]
        if repetitions.isEmpty {
            iterations = [ParsedIteration(
                iterationNumber: nil,
                status: Self.status(node.result),
                duration: node.durationInSeconds ?? 0,
                activities: mergingFailureMessages(
                    failureMessages(of: node),
                    into: activities(for: identifier, iteration: nil)
                )
            )]
        } else {
            // The parent node's own `result` summarises the retries and is not
            // the legacy status: a test that failed then passed reports
            // "Passed" here while legacy reports mixed. Derive from children.
            iterations = repetitions.enumerated().map { index, repetition in
                ParsedIteration(
                    iterationNumber: repetition.nodeIdentifier.flatMap(Int.init)
                        ?? (index + 1),
                    status: Self.status(repetition.result),
                    duration: repetition.durationInSeconds ?? 0,
                    activities: mergingFailureMessages(
                        failureMessages(of: repetition),
                        into: activities(for: identifier, iteration: index)
                    )
                )
            }
        }

        return ParsedTestCase(
            name: node.name ?? "",
            identifier: identifier,
            arguments: Self.arguments(of: node),
            iterations: iterations
        )
    }

    private func failureMessages(of node: TestNode) -> [String] {
        (node.children ?? [])
            .filter { $0.nodeType == "Failure Message" }
            .compactMap(\.name)
    }

    /// Joins the tests document's `Failure Message` nodes onto the activity
    /// tree.
    ///
    /// Both documents describe the same failure, each holding half of it. The
    /// `Failure Message` node keeps the `file:line` prefix
    /// (`"FirstSuite.swift:86: XCTAssertTrue failed - Test failed"`) but has
    /// no timestamp; the activities document reports the failure as a
    /// failure-flagged activity row — positioned and timestamped, nested
    /// inside the user's own activity when the assertion fired there — but
    /// drops the prefix. Sourcing titles from activities loses `file:line`
    /// everywhere; appending messages unconditionally renders two rows per
    /// failure.
    ///
    /// So: each message claims the first failure-flagged activity — pre-order,
    /// document order, first-unmatched-first, which pairs repeated identical
    /// assertions deterministically — whose title is an exact suffix of the
    /// message, and that activity is retitled with the message as given,
    /// keeping its position, nesting, start, attachments and children. The
    /// string is never parsed apart: rebuilding `fileName`/`lineNumber` from
    /// it would put visible UI on an inferred parse of a format Apple can
    /// reformat without notice (see the spec's "Failure location").
    ///
    /// Messages that match nothing still append as failure rows at the end —
    /// skip reasons and expected-failure notes ride the same node type, and
    /// their activity twins are not failure-flagged, so they have no row to
    /// claim and no timestamp to interleave on.
    private func mergingFailureMessages(
        _ messages: [String],
        into activities: [ParsedActivity]
    ) -> [ParsedActivity] {
        guard !messages.isEmpty else {
            return activities
        }

        var candidates: [(path: [Int], title: String)] = []
        func collect(_ activities: [ParsedActivity], _ prefix: [Int]) {
            for (index, activity) in activities.enumerated() {
                let path = prefix + [index]
                if activity.isFailure, !activity.title.isEmpty {
                    candidates.append((path, activity.title))
                }
                collect(activity.subActivities, path)
            }
        }
        collect(activities, [])

        var retitles: [[Int]: String] = [:]
        var appended: [ParsedActivity] = []
        for message in messages {
            if let match = candidates.first(where: {
                retitles[$0.path] == nil && message.hasSuffix($0.title)
            }) {
                retitles[match.path] = message
            } else {
                appended.append(ParsedActivity(
                    title: message,
                    isFailure: true,
                    start: nil,
                    attachments: [],
                    subActivities: []
                ))
            }
        }

        func rebuild(_ activities: [ParsedActivity], _ prefix: [Int]) -> [ParsedActivity] {
            activities.enumerated().map { index, activity in
                let path = prefix + [index]
                return ParsedActivity(
                    title: retitles[path] ?? activity.title,
                    isFailure: activity.isFailure,
                    start: activity.start,
                    attachments: activity.attachments,
                    subActivities: rebuild(activity.subActivities, path)
                )
            }
        }
        return (retitles.isEmpty ? activities : rebuild(activities, [])) + appended
    }

    /// One `activities` subprocess per exact test-case id — suite and bundle
    /// ids are rejected by the tool, so there is nothing to batch. `testRuns`
    /// holds one entry per repetition, in order.
    private func activities(for identifier: String, iteration: Int?) -> [ParsedActivity] {
        guard !identifier.isEmpty else {
            return []
        }
        do {
            let document = try client.json(
                ["get", "test-results", "activities", "--test-id", identifier],
                as: TestActivities.self
            )
            let runs = document.testRuns ?? []
            let run: TestActivities.TestRun? = iteration
                .flatMap { index in runs.indices.contains(index) ? runs[index] : nil }
                ?? runs.first
            return (run?.activities ?? []).map(parseActivity)
        } catch {
            // A failed activities query is a genuine read failure, not a
            // format limitation: the test renders with no activities at all.
            // Without a fault the CLI would exit 0 on a visibly gutted report.
            Logger.warning("Can't read activities for \(identifier): \(error.localizedDescription)")
            faultCollector.record(.missingActivities, identifier)
            return []
        }
    }

    private func parseActivity(_ node: ActivityNode) -> ParsedActivity {
        ParsedActivity(
            title: node.title ?? "",
            isFailure: node.isAssociatedWithFailure ?? false,
            start: node.startTime.map { Date(timeIntervalSince1970: $0) },
            attachments: (node.attachments ?? []).map(parseAttachment),
            subActivities: (node.childActivities ?? []).map(parseActivity)
        )
    }

    private func parseAttachment(_ attachment: ActivityAttachment) -> ParsedAttachment {
        let exported = attachment.uuid.flatMap { payloadStore?.exportedFileName(uuid: $0) }
        // Prefer the attachment's own filename; fall back to the exported
        // file. Both are `<something>.<ext>`, and this matches the order
        // `LegacyResultReader.filenameExtension(forUTI:filename:)` uses, so
        // the two backends type attachments identically.
        let ext = [attachment.name, exported]
            .compactMap { $0 }
            .map { ($0 as NSString).pathExtension.lowercased() }
            .first { !$0.isEmpty }
        return ParsedAttachment(
            // `name` in the new format holds what legacy calls `filename`; the
            // user-supplied name is not exposed. Report it as filename only.
            name: nil,
            filename: attachment.name,
            filenameExtension: ext,
            payloadReference: attachment.uuid
        )
    }
}
