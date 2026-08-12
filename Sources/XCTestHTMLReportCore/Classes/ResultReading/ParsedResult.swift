//
//  ParsedResult.swift
//  XCTestHTMLReportCore
//
//  Backend-neutral representation of one .xcresult bundle. Both the legacy
//  (XCResultKit) and modern (xcresulttool) readers produce this, and the
//  renderer consumes only this.
//
//  "Backend-neutral" is a constraint, not a description: a field only one
//  backend can populate does not belong here. Per-activity finish times,
//  activity types, and attachment UTIs were all removed for that reason (see
//  "Deciding the model before the port" in the design spec) — the legacy
//  backend stops rendering them too, so the two agree by construction rather
//  than by mask.
//
//  What remains optional is genuinely optional on both sides: a repetition
//  number a non-repeated test has no value for, a filename an anonymous
//  attachment never had. Their absence is never a Fault.
//

import Foundation

public struct ParsedResult {
    public let runs: [ParsedRun]
}

public struct ParsedRun {
    public let destination: ParsedDestination
    public let logReference: String?
    public let testables: [ParsedTestable]
}

public struct ParsedDestination {
    public let displayName: String
    public let deviceIdentifier: String
    public let modelName: String
    public let operatingSystemVersion: String
}

/// One test target within a run — `ActionTestableSummary` on legacy, a
/// `UI test bundle` / `Unit test bundle` node on modern.
public struct ParsedTestable {
    public let targetName: String
    public let groups: [ParsedGroup]
}

public indirect enum ParsedNode {
    case group(ParsedGroup)
    case testCase(ParsedTestCase)
}

public struct ParsedGroup {
    public let name: String
    public let identifier: String
    public let duration: TimeInterval
    public let children: [ParsedNode]
}

/// A test method. Carries one entry per repetition; a non-repeated test has
/// exactly one.
public struct ParsedTestCase {
    public let name: String
    public let identifier: String
    /// Swift Testing `@Test(arguments:)` values, from the modern format's
    /// `Arguments` nodes. Empty on legacy, which has no counterpart, and empty
    /// for non-parameterized tests.
    ///
    /// Present now rather than later because it is *inside* the tree: adding
    /// the slot afterwards means reshaping the port and every reader with it.
    /// Not yet exercised by any fixture — see Task 8 of the migration plan.
    public let arguments: [String]
    public let iterations: [ParsedIteration]
}

/// Test outcome, in neither backend's spelling.
///
/// Legacy says `Success`/`Failure`; modern says `Passed`/`Failed`. Carrying
/// either as a raw string would force the other reader to emit words it never
/// saw. Each reader maps into this; the spec's status table defines both
/// mappings.
public enum ParsedStatus: Equatable {
    case passed
    case failed
    case skipped
    case expectedFailure
    case unknown
}

public struct ParsedIteration {
    /// 1-based. `nil` when the backend reports no repetition information.
    public let iterationNumber: Int?
    public let status: ParsedStatus
    public let duration: TimeInterval
    public let activities: [ParsedActivity]
}

public struct ParsedActivity {
    public let title: String
    /// True when the backend marks this activity as a failure. Legacy derives
    /// it from `activityType`; modern reads `isAssociatedWithFailure`.
    ///
    /// This is all that survives of the legacy activity taxonomy. The other
    /// four states have no modern source, so they are out of the port rather
    /// than nil on one side of it.
    public let isFailure: Bool
    /// Start only. Modern publishes no finish time, so per-activity duration
    /// is not representable — and a fabricated `(0.00s)` is worse than none.
    public let start: Date?
    public let attachments: [ParsedAttachment]
    public let subActivities: [ParsedActivity]
}

public struct ParsedAttachment {
    /// User-supplied name. `nil` on the modern backend, which exposes only the
    /// generated filename. One of the genuine remaining asymmetries.
    public let name: String?
    public let filename: String?
    /// Lowercased, without a leading dot. Both backends supply this: legacy
    /// maps its UTI down to an extension, modern reads it off the exported
    /// filename. `AttachmentType` needs no more than this to pick a template
    /// and a MIME type.
    public let filenameExtension: String?
    /// Opaque handle the backend's payload provider resolves to bytes.
    public let payloadReference: String?
}
