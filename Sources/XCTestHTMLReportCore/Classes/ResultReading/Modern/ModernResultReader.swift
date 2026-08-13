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
            let status = Self.status(node.result)
            iterations = [ParsedIteration(
                iterationNumber: nil,
                status: status,
                duration: node.durationInSeconds ?? 0,
                activities: hoistingFailureRows(joiningFailureMessages(
                    failureMessages(of: node),
                    into: activities(for: identifier, iteration: nil),
                    status: status
                ))
            )]
        } else {
            // The parent node's own `result` summarises the retries and is not
            // the legacy status: a test that failed then passed reports
            // "Passed" here while legacy reports mixed. Derive from children.
            iterations = repetitions.enumerated().map { index, repetition in
                let status = Self.status(repetition.result)
                return ParsedIteration(
                    iterationNumber: repetition.nodeIdentifier.flatMap(Int.init)
                        ?? (index + 1),
                    status: status,
                    duration: repetition.durationInSeconds ?? 0,
                    activities: hoistingFailureRows(joiningFailureMessages(
                        failureMessages(of: repetition),
                        into: activities(for: identifier, iteration: index),
                        status: status
                    ))
                )
            }
        }

        return ParsedTestCase(
            // The identifier's last component, not `node.name`. For XCTest the
            // two are the same string; for Swift Testing `node.name` is the
            // `@Test` display name ("Tagged multiplication check"), which the
            // legacy format cannot see. A name only one backend can fill does
            // not belong in the port (the same rule that removed
            // `activityType`), so both readers carry the function-form name
            // the identifier gives them. The display name is deliberately
            // unused until the redesign models it.
            name: identifier.isEmpty
                ? (node.name ?? "")
                : (identifier.components(separatedBy: "/").last ?? node.name ?? ""),
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
            return (run?.activities ?? []).map { parseActivity(pruning: $0) }
        } catch {
            // A failed activities query is a genuine read failure, not a
            // format limitation: the test renders with no activities at all.
            // Without a fault the CLI would exit 0 on a visibly gutted report.
            Logger.warning("Can't read activities for \(identifier): \(error.localizedDescription)")
            faultCollector.record(.missingActivities, identifier)
            return []
        }
    }

    /// Translates an activity node, dropping two families of bookkeeping rows
    /// Xcode 26.2 nests inside real activities and the legacy tree never had:
    ///
    /// 1. **Symbol annotations** — children with no `startTime`, titled with
    ///    the failing frame (`RetryTests.testJustFail()`, `closure #1 in …`).
    ///    The timeline model orders on `start` (answer 1); a row without one
    ///    is an annotation, not an event. A no-start row that carries
    ///    attachments, a failure flag, or surviving children is **kept**, not
    ///    dropped: dropping content because a future format variant stopped
    ///    stamping times would silently gut real data, and rendering it
    ///    unordered is the lesser harm.
    ///
    /// 2. **Attachment shadows** — for every attachment the document also
    ///    emits one childless, non-failure child row whose `startTime` equals
    ///    the attachment's `timestamp` (its title is the attachment's
    ///    user-supplied name, which the spec deliberately does not mine — see
    ///    "Reconstructing lost fields by heuristic"). The row is the
    ///    attachment's shadow, so it is claimed by the timestamp join and
    ///    dropped, mirroring the failure-message join below. The leaf and
    ///    non-failure guards are load-bearing: a genuine failure row can share
    ///    the attachment's millisecond (observed on
    ///    `testWithSpecialChars()`), and must survive.
    private func parseActivity(pruning node: ActivityNode) -> ParsedActivity {
        let attachmentTimes = Set((node.attachments ?? []).compactMap(\.timestamp))
        let children: [ParsedActivity] = (node.childActivities ?? []).compactMap { child in
            let parsed = parseActivity(pruning: child)
            let hasContent = parsed.isFailure || !parsed.attachments.isEmpty
                || !parsed.subActivities.isEmpty
            guard !hasContent else {
                return parsed
            }
            if child.startTime == nil {
                return nil // symbol annotation
            }
            if let start = child.startTime, attachmentTimes.contains(start) {
                return nil // attachment shadow
            }
            return parsed
        }
        // Tip-of-chain, not the raw flag: the new format sets
        // `isAssociatedWithFailure` on every ancestor of a failure, while the
        // port's `isFailure` means "this row IS the assertion row". The tip is
        // the flagged node with no flagged children; containers revert to
        // plain activities, and the renderer derives containment itself. A
        // chain with several assertion rows has several tips — each flagged
        // node without flagged children qualifies independently.
        let flagged = node.isAssociatedWithFailure ?? false
        let childFlagged = (node.childActivities ?? [])
            .contains { $0.isAssociatedWithFailure ?? false }
        return ParsedActivity(
            title: node.title ?? "",
            isFailure: flagged && !childFlagged,
            start: node.startTime.map { Date(timeIntervalSince1970: $0) },
            attachments: (node.attachments ?? []).map(parseAttachment),
            subActivities: children
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
            // The user-supplied name is not exposed by the new format; the
            // display name falls back to the type-derived label (the
            // `attachmentDisplayNames` allow-list entry).
            name: nil,
            // Content-addressed, not `attachment.name`: Xcode 26.2 gives every
            // auto screen recording in a session one shared display name, so
            // naming exports after it collapsed distinct payloads onto one
            // path and raced concurrent copies (#449). `payloadId` is the same
            // CAS id legacy calls `payloadRef.id`, so both backends derive the
            // identical name — see `ParsedAttachment.exportFileName`.
            filename: attachment.payloadId.map {
                ParsedAttachment.exportFileName(payloadId: $0, filenameExtension: ext)
            },
            filenameExtension: ext,
            payloadReference: attachment.uuid
        )
    }
}
