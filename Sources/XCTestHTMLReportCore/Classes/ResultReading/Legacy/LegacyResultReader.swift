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
                iterations: iterations
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
        let combined: [ParsedActivity]
        if activities.contains(where: hasFailure) {
            combined = activities
        } else {
            let failures = summary.failureSummaries.map(parseFailure)
            // Ordered by `start`, which replaced `finish` as the ordering key
            // under decision 1 — the modern format publishes no finish, so
            // `start` is the only key both backends share. This sort is not
            // cosmetic: it interleaves assertion-failure rows among the
            // activities so a failure renders *where it occurred* rather than
            // after everything else. Dropping it — rather than re-keying it —
            // would silently append every failure row at the end of the test.
            combined = (activities + failures).sorted {
                ($0.start ?? .distantPast) < ($1.start ?? .distantPast)
            }
        }

        return ParsedIteration(
            iterationNumber: summary.repetitionPolicySummary?.iteration,
            status: Self.status(metadata.testStatus),
            duration: metadata.duration ?? 0,
            activities: combined
        )
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
        ParsedAttachment(
            name: attachment.name,
            filename: attachment.filename,
            // The port carries no UTI (answer 4). Map it down to an extension
            // here so both backends type attachments identically instead of
            // the difference being allow-listed.
            filenameExtension: Self.filenameExtension(
                forUTI: attachment.uniformTypeIdentifier,
                filename: attachment.filename
            ),
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
