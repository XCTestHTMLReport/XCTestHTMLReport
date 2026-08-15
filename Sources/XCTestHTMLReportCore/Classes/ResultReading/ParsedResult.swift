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

/// The truncation signal `Summary.validate()` reads (#478). It lives here, on
/// the shared model, rather than in either reader, so there is one
/// implementation rather than two to keep in step — the same argument
/// `ParsedActivity.interleavingFailureRows` makes for failure-row ordering.
///
/// One implementation is not by itself a guarantee that both backends behave
/// alike: shared code over unequal input still diverges, which is how the
/// withdrawn `emptyPlannedTestable` managed to fire on legacy only. What makes
/// this one agree is that the node it keys on was measured on both readers,
/// from the same bundle, and is re-measured on every toolchain by
/// `SystemFailureCanaryTests`.
extension ParsedGroup {
    /// The group Apple files host-app and system failures under.
    ///
    /// Not a heuristic reading of a message: it is the node's own name, and
    /// both formats spell it identically at the same position in the tree.
    /// Measured, not assumed — `prepareTestResults.sh` generates
    /// `CrashResults.xcresult` by trapping in the host app's
    /// `didFinishLaunchingWithOptions`, and both readers put out a group whose
    /// `name` and `identifier` are `System Failures`, directly under the
    /// testable.
    ///
    /// The group is the marker rather than its rows precisely because the rows
    /// are where the two backends stop agreeing: modern carries the crash row
    /// (`SampleApp (<pid>) encountered an error`, with the bootstrap failure as
    /// its failure activity), while XCResultKit drops it — the node is an
    /// `ActionTestSummary`, not one of the `ActionTestMetadata` entries
    /// `subtests` decodes — so legacy sees the bucket empty. Keying on the
    /// bucket makes the rule fire on both; keying on the row would have made it
    /// fire only on modern.
    ///
    /// Two consequences of keying on a display name, both accepted knowingly:
    ///
    /// - **A rename disarms the rule silently.** The bucket is a plain test
    ///   suite on both surfaces — modern's node is
    ///   `{"name": "System Failures", "nodeType": "Test Suite"}`, legacy's an
    ///   ordinary `ActionTestSummaryGroup` — so nothing structural
    ///   distinguishes it from a user's own suite, and there is no other
    ///   surface to detect it on today. If Apple renames it, healthy fixtures
    ///   go on passing and nothing reddens. That is what
    ///   `SystemFailureCanaryTests` is for: it asserts a freshly generated
    ///   crash bundle still contains this literal, on both readers, so the
    ///   rename fails the suite on the toolchain that introduces it — and the
    ///   `toolchain-drift` beta leg reaches that toolchain before a release
    ///   does. The literal appears in no binary and no `.strings` table under
    ///   `Xcode.app`; it is written into the bundle at run time, which is weak
    ///   evidence it is not localized, and no evidence at all that it is
    ///   permanent.
    /// - **A user suite named `System Failures` faults.** Contrived, and it
    ///   costs that user one `--lenient` run, which is the cheaper side of the
    ///   trade against missing a real crash.
    static let systemFailureName = "System Failures"

    /// Every test row in this group's subtree, at any depth.
    var allTestCases: [ParsedTestCase] {
        children.flatMap { child -> [ParsedTestCase] in
            switch child {
            case let .testCase(testCase):
                return [testCase]
            case let .group(group):
                return group.allTestCases
            }
        }
    }

    /// Every `System Failures` group in this subtree, including this one.
    ///
    /// Recursive, though both backends put the bucket directly under the
    /// testable today: the name is Apple's, so a nested one is still a system
    /// failure, and for a fault whose whole job is catching a run that stopped
    /// early, missing a relocated bucket is the worse way to be wrong.
    var systemFailureGroups: [ParsedGroup] {
        let nested = children
            .compactMap { child -> ParsedGroup? in
                guard case let .group(group) = child else {
                    return nil
                }
                return group
            }
            .flatMap(\.systemFailureGroups)
        return (name == Self.systemFailureName ? [self] : []) + nested
    }
}

extension ParsedTestable {
    var systemFailureGroups: [ParsedGroup] {
        groups.flatMap(\.systemFailureGroups)
    }
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
    /// How many times the run actually executed this test (#439, A3b).
    ///
    /// Xcode's own toolbar states 21 tests and 23 *runs* on `TestResults`, and
    /// the two differ for exactly one reason here: `parameterizedAddition`
    /// executed once per argument set. `iterations` cannot carry that number —
    /// both readers deliberately collapse argument executions into one row, so
    /// a parameterized case has one iteration on either backend — and
    /// `arguments` cannot either, because only the modern format names the
    /// values.
    ///
    /// What *both* formats carry is the count, and this is where it lands:
    ///
    /// - legacy: the number of sibling metadata entries sharing the identifier,
    ///   taken before `mergingArgumentExecutions` folds them;
    /// - modern: the number of `Repetition` children, or of `Arguments`
    ///   children when there are no repetitions.
    ///
    /// So this converges the readers rather than reading something new: the
    /// fact was in both bundles and one of them was throwing it away.
    /// `DifferentialTests.testExecutionCountsAgreeAcrossBackends` is what holds
    /// them equal, and `1` is the floor — a test that ran once.
    ///
    /// A test that is *both* parameterized and repeated is not exercised by
    /// any fixture, and what either reader derives for it is not knowable from
    /// here: legacy's answer is however many sibling entries that format
    /// happens to emit for the combination, and modern's turns on where the
    /// `Repetition` nodes sit — `R` if they nest under `Arguments`, `max(R, A)`
    /// if the two are siblings. Nothing in the report depends on that shape
    /// today, and `testExecutionCountsAgreeAcrossBackends` is the gate that
    /// would fail and name the identifier if a bundle ever carried one; closing
    /// it needs that fixture first.
    public let executionCount: Int
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
    /// True when this row *is* the failure row itself — the assertion (or the
    /// appended failure message), not an activity that merely contains one.
    /// Legacy derives it from `activityType ==
    /// testAssertionFailure`; modern maps the tip of the
    /// `isAssociatedWithFailure` chain, because the new format flags every
    /// ancestor of a failure and the renderer already derives containment on
    /// its own (`Activity.hasFailingSubActivities`).
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

    /// Interleaves an iteration's failure rows among its top-level activities.
    ///
    /// One function, called by **both** readers, is what makes the two
    /// backends' failure-row placement agree by construction: legacy feeds it
    /// the separate `failureSummaries` list its format keeps (post-3.39
    /// xcresulttool no longer nests assertions inside activities), and the
    /// modern reader feeds it the failure tips it hoists out of its natively
    /// nested tree. Neither side may sort these rows independently.
    ///
    /// The order is **total** — `(start, kind, source index)`:
    ///  - `start`, with `nil` sorting *last* (`.distantFuture`): a row with no
    ///    timestamp is an unpositioned annotation (an appended failure
    ///    message, a skip notice) and belongs after the timeline, which is
    ///    where the modern reader's append path has always put it.
    ///  - on equal starts, activities precede failure rows — assertion
    ///    timestamps routinely equal their enclosing activity's start at the
    ///    format's millisecond granularity, so this tie is hit in practice,
    ///    not hypothetically.
    ///  - source index last, so the order is deterministic even for identical
    ///    rows. A non-total comparator here regressed once before (#443);
    ///    `PortRuleTests` pins totality directly.
    public static func interleavingFailureRows(
        activities: [ParsedActivity],
        failureRows: [ParsedActivity]
    ) -> [ParsedActivity] {
        struct Keyed {
            let start: Date
            let kind: Int
            let index: Int
            let row: ParsedActivity
        }
        let keyed = activities.enumerated().map {
            Keyed(
                start: $0.element.start ?? .distantFuture,
                kind: 0,
                index: $0.offset,
                row: $0.element
            )
        }
            + failureRows.enumerated().map {
                Keyed(
                    start: $0.element.start ?? .distantFuture,
                    kind: 1,
                    index: $0.offset,
                    row: $0.element
                )
            }
        return keyed
            .sorted { lhs, rhs in
                if lhs.start != rhs.start {
                    return lhs.start < rhs.start
                }
                if lhs.kind != rhs.kind {
                    return lhs.kind < rhs.kind
                }
                return lhs.index < rhs.index
            }
            .map(\.row)
    }
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

    /// The on-disk name an exported payload gets, derived from the payload's
    /// content-addressed store id — the one attachment identifier both formats
    /// share (legacy `payloadRef.id`, modern `payloadId` — the same CAS id).
    ///
    /// Naming exports after backend-native pretty names is what this replaces,
    /// and it broke two ways at once: legacy filenames embed a legacy-only
    /// uuid the modern format cannot see, and Xcode 26.2 gives every auto
    /// screen recording in a session one shared display name, so distinct
    /// payloads collapsed onto one path and concurrent copies raced on it
    /// (#449). A content-addressed name is unique per payload by construction,
    /// makes the export idempotent, and both backends produce it from shared
    /// data — filenames agree by construction rather than by mask.
    ///
    /// The id's alphabet is `0~` + base64url + `=` padding, all safe in a
    /// POSIX filename; `/` is replaced defensively in case a future tool
    /// switches to plain base64.
    public static func exportFileName(
        payloadId: String, filenameExtension: String?
    ) -> String {
        let stem = payloadId.replacingOccurrences(of: "/", with: "_")
        guard let ext = filenameExtension, !ext.isEmpty else {
            return stem
        }
        return "\(stem).\(ext)"
    }
}
