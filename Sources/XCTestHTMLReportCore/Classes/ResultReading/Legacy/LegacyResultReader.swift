//
//  LegacyResultReader.swift
//  XCTestHTMLReportCore
//
//  Translates XCResultKit's object graph into ParsedResult. This is the only
//  file in the target that imports XCResultKit; it is deleted wholesale once
//  Apple removes the legacy commands.
//

import Foundation
import XCResultKit

struct LegacyResultReader: ResultReader {
    let file: ResultFile

    func read() -> ParsedResult? {
        guard let record = file.getInvocationRecord() else {
            return nil
        }
        let runs = record.actions.compactMap(parseRun)
        // Same rule as the modern reader: a decodable document that yields no
        // runs is a failed read, not an empty result. Returning
        // `ParsedResult(runs: [])` would satisfy `Summary.init`'s `guard let`,
        // record no fault, and let `--lenient` write an empty report and exit
        // 0. Decoding succeeding is not evidence the bundle had content.
        guard !runs.isEmpty else {
            Logger.warning("No runs parsed from \(file.url.lastPathComponent)")
            return nil
        }
        return ParsedResult(runs: runs)
    }

    private func parseRun(_ action: ActionRecord) -> ParsedRun? {
        guard
            let testsRef = action.actionResult.testsRef,
            let plan = file.getTestPlanRunSummaries(id: testsRef.id)
        else {
            Logger.warning("Can't find test reference for action \(action.title ?? "")")
            return nil
        }
        let device = action.runDestination.targetDeviceRecord
        return ParsedRun(
            destination: ParsedDestination(
                displayName: action.runDestination.displayName,
                deviceIdentifier: device.identifier,
                modelName: device.modelName,
                operatingSystemVersion: device.operatingSystemVersion
            ),
            logReference: action.actionResult.logRef?.id,
            testables: plan.summaries.flatMap(\.testableSummaries).map { summary in
                ParsedTestable(
                    targetName: summary.targetName ?? "",
                    groups: summary.tests.map(parseGroup)
                )
            }
        )
    }

    private func parseGroup(_ group: ActionTestSummaryGroup) -> ParsedGroup {
        // Legacy lists each repetition as its own sibling metadata entry under
        // one identifier. Merge them here so the renderer sees one test case
        // with N iterations, which is what TestGroup.init used to do inline.
        var order: [String] = []
        var buckets: [String: [ActionTestMetadata]] = [:]
        for metadata in group.subtests {
            let identifier = metadata.identifier ?? ""
            if buckets[identifier] == nil {
                order.append(identifier)
            }
            buckets[identifier, default: []].append(metadata)
        }

        let cases: [ParsedNode] = order.map { identifier in
            let entries = buckets[identifier] ?? []
            // Repetition numbers are not necessarily distinct (older bundles
            // have none at all), so break ties on source position to keep this
            // a total order — the same tiebreak `TestCase.merge` used.
            let iterations = entries
                .map(parseIteration)
                .enumerated()
                .sorted { ($0.element.iterationNumber ?? 0, $0.offset) <
                    ($1.element.iterationNumber ?? 0, $1.offset)
                }
                .map(\.element)
            return .testCase(ParsedTestCase(
                name: entries.first?.name ?? "",
                identifier: identifier,
                // Legacy has no counterpart to Swift Testing's Arguments nodes.
                arguments: [],
                iterations: Self.mergingArgumentExecutions(iterations)
            ))
        }

        return ParsedGroup(
            name: group.name ?? "---group-name-not-found---",
            identifier: group.identifier ?? "---group-identifier-not-found---",
            duration: group.duration,
            children: cases + group.subtestGroups.map { .group(parseGroup($0)) }
        )
    }

    private func parseIteration(_ metadata: ActionTestMetadata) -> ParsedIteration {
        guard
            let id = metadata.summaryRef?.id,
            let summary = file.getActionTestSummary(id: id)
        else {
            return ParsedIteration(
                iterationNumber: nil,
                status: Self.status(metadata.testStatus),
                duration: metadata.duration ?? 0,
                activities: []
            )
        }

        let activities = summary.activitySummaries.map(parseActivity)

        // As of xcresulttool 3.39 assertion failures are no longer nested in
        // ActionTestActivitySummary, so failure summaries are interleaved by
        // start time. When failing sub-activities are already present we are
        // on an older tool and must not add them twice.
        let failures: [ParsedActivity]
        if activities.contains(where: hasFailure) {
            failures = []
        } else {
            failures = summary.failureSummaries.map(parseFailure)
        }

        // The skip reason lives on its own summary object, which this reader
        // previously never read — the modern reader has always surfaced the
        // equivalent `Failure Message` node, so skipping it here was a reader
        // gap, not a format limitation. Same shape as the modern append path:
        // a failure row with no timestamp, which the shared interleaving
        // orders after the timeline.
        let skipNotice: [ParsedActivity] = (summary.skipNoticeSummary?.message).map {
            [ParsedActivity(
                title: $0, isFailure: true, start: nil, attachments: [], subActivities: []
            )]
        } ?? []

        // The interleave — `start`-keyed, per decision 1 — is not cosmetic:
        // it renders each failure row *where it occurred* rather than after
        // everything else. It lives in the port
        // (`ParsedActivity.interleavingFailureRows`) because both readers
        // must place these rows identically, and one shared function is the
        // only ordering rule that cannot drift.
        let combined = ParsedActivity.interleavingFailureRows(
            activities: activities,
            failureRows: failures + skipNotice
        )

        return ParsedIteration(
            iterationNumber: summary.repetitionPolicySummary?.iteration,
            status: Self.status(metadata.testStatus),
            duration: metadata.duration ?? 0,
            activities: combined
        )
    }

    /// Collapses Swift Testing argument executions into one iteration.
    ///
    /// A parameterized `@Test(arguments:)` reaches the legacy format as
    /// duplicate sibling metadata entries sharing one identifier — the same
    /// encoding as retries, except none of them carries a
    /// `repetitionPolicySummary`. Rendering them as repetitions invents retry
    /// semantics for what are argument variations ("3 succeeded", three
    /// "Iteration 0" rows), and the modern format renders the same test as a
    /// single case with `Arguments` children (answer 6). Merging on the
    /// absence of repetition metadata makes both backends agree by
    /// construction: durations sum (the rule answer 8 already sets), and
    /// activities concatenate in source order.
    ///
    /// True retries are untouched: every `-retry-tests-on-failure` repetition
    /// carries the policy summary, so at least one iteration has a number and
    /// the merge does not fire. `RetryResults` pins that in the fixture suite.
    static func mergingArgumentExecutions(
        _ iterations: [ParsedIteration]
    ) -> [ParsedIteration] {
        guard iterations.count > 1,
              iterations.allSatisfy({ $0.iterationNumber == nil })
        else {
            return iterations
        }
        let statuses = Set(iterations.map(\.status))
        let merged: ParsedStatus
        if statuses.count == 1 {
            merged = statuses.first ?? .unknown
        } else if statuses.contains(.failed) {
            // Mirrors the modern parent node's own summary: passed only when
            // every argument passed.
            merged = .failed
        } else if statuses.contains(.skipped) {
            merged = .skipped
        } else {
            merged = .unknown
        }
        return [ParsedIteration(
            iterationNumber: nil,
            status: merged,
            duration: iterations.reduce(0) { $0 + $1.duration },
            activities: iterations.flatMap(\.activities)
        )]
    }

    /// Legacy spellings into the neutral enum. The modern reader has the
    /// mirror of this; neither emits the other's vocabulary.
    static func status(_ raw: String) -> ParsedStatus {
        switch raw {
        case "Success": return .passed
        case "Failure": return .failed
        case "Skipped": return .skipped
        case "Expected Failure": return .expectedFailure
        default: return .unknown
        }
    }

    private func hasFailure(_ activity: ParsedActivity) -> Bool {
        activity.isFailure || activity.subActivities.contains(where: hasFailure)
    }

    private func parseActivity(_ summary: ActionTestActivitySummary) -> ParsedActivity {
        ParsedActivity(
            title: summary.title,
            // `activityType` is read only to derive this flag; the taxonomy
            // itself is out of the port (answer 2). `finish` is dropped
            // likewise (answer 1) — legacy has it, but keeping it would mean
            // the two backends disagree on every activity's duration.
            isFailure: summary.activityType
                == "com.apple.dt.xctest.activity-type.testAssertionFailure",
            start: summary.start,
            attachments: summary.attachments.map(parseAttachment),
            subActivities: summary.subactivities.map(parseActivity)
        )
    }

    private func parseFailure(_ summary: ActionTestFailureSummary) -> ParsedActivity {
        let issueType = summary.issueType ?? "Assertion Failure"
        let message = summary.message ?? "[message not provided]"
        let file = summary.fileName?.lastPathComponent() ?? ""
        return ParsedActivity(
            title: "\(issueType) at \(file):\(summary.lineNumber):\(message)",
            isFailure: true,
            start: summary.timestamp,
            attachments: summary.attachments.map(parseAttachment),
            subActivities: []
        )
    }

    private func parseAttachment(_ attachment: ActionTestAttachment) -> ParsedAttachment {
        // The port carries no UTI (answer 4). Map it down to an extension
        // here so both backends type attachments identically instead of
        // the difference being allow-listed.
        let ext = Self.filenameExtension(
            forUTI: attachment.uniformTypeIdentifier,
            filename: attachment.filename
        )
        return ParsedAttachment(
            name: attachment.name,
            // Content-addressed, not `attachment.filename`: the legacy pretty
            // name embeds a legacy-only uuid the modern format cannot see, so
            // it can never agree across backends. The payload id can — see
            // `ParsedAttachment.exportFileName`. An attachment with no payload
            // has nothing to export and gets no filename, on both backends.
            filename: attachment.payloadRef.map {
                ParsedAttachment.exportFileName(payloadId: $0.id, filenameExtension: ext)
            },
            filenameExtension: ext,
            payloadReference: attachment.payloadRef?.id
        )
    }

    /// Prefers the filename's own extension and falls back to the UTI.
    ///
    /// Legacy filenames are `<name>_<n>_<uuid>.<ext>`, so the extension is
    /// normally right there. `UTType` would be the direct route but is macOS
    /// 11+, and the floor here is 10.15, so the fallback is an explicit table —
    /// the same shape `Attachment.swift` already uses for MIME types.
    static func filenameExtension(forUTI uti: String?, filename: String?) -> String? {
        if let filename = filename,
           case let ext = (filename as NSString).pathExtension, !ext.isEmpty
        {
            return ext.lowercased()
        }
        switch uti {
        case "public.png": return "png"
        case "public.jpeg": return "jpeg"
        case "public.heic": return "heic"
        case "com.compuserve.gif": return "gif"
        case "public.mpeg-4": return "mp4"
        case "public.plain-text": return "txt"
        case "com.apple.log": return "log"
        case "public.html": return "html"
        case "public.zip-archive": return "zip"
        // `public.data` is itself an `AttachmentType` raw value; without this
        // entry an extensionless data attachment degrades `.data` → `.unknown`.
        case "public.data": return "dat"
        default: return nil
        }
    }
}
