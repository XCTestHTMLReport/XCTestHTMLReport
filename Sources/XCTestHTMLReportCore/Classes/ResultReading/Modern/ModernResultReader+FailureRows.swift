//
//  ModernResultReader+FailureRows.swift
//  XCTestHTMLReportCore
//
//  How the tests document's `Failure Message` nodes and the activities
//  document's failure-flagged rows become the port's failure rows: the join
//  that reunites the two halves of one failure, its inversion for expected
//  failures, and the hoist that puts the result where the legacy backend can
//  agree with it.
//

import Foundation

extension ModernResultReader {
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
    /// skip reasons ride the same node type, and their activity twins are not
    /// failure-flagged, so they have no row to claim and no timestamp to
    /// interleave on.
    ///
    /// **Expected failures invert the join.** The legacy report treats an
    /// expected failure as a non-event — status flattens to `.unknown` and
    /// nothing renders — while the modern documents carry both the `Failure
    /// Message` (the `XCTExpectFailure` text) and a matching activity row.
    /// For a test whose result is `Expected Failure`, each message therefore
    /// claims and **removes** the first activity whose title equals the
    /// message exactly — exact match only, never fuzzy — subtree included,
    /// and messages that match nothing are suppressed rather than appended.
    func joiningFailureMessages(
        _ messages: [String],
        into activities: [ParsedActivity],
        status: ParsedStatus
    ) -> [ParsedActivity] {
        guard status != .expectedFailure else {
            return removingExpectedFailureRows(messages, from: activities)
        }
        return mergingFailureMessages(messages, into: activities)
    }

    /// Hoists failure rows out of the nested tree and interleaves them at the
    /// top level, through the same shared ordering the legacy reader uses.
    ///
    /// The new format nests an assertion row inside the activity it fired in;
    /// the legacy format structurally cannot (post-3.39 failure summaries are
    /// separate objects), and re-nesting them by `[start, finish]` window was
    /// tested and rejected — at the format's millisecond granularity the
    /// windows collide and the join misplaces rows. So the modern reader
    /// discards the nesting instead: hoisted rows keep their own subtree,
    /// title, timestamp and attachments, only their position changes. This is
    /// a deliberate scaffold constraint, not a design preference — once the
    /// legacy backend is removed, this hoist can be deleted and the report
    /// may show the native nesting again.
    func hoistingFailureRows(_ activities: [ParsedActivity]) -> [ParsedActivity] {
        var failureRows: [ParsedActivity] = []
        func strip(_ list: [ParsedActivity]) -> [ParsedActivity] {
            list.compactMap { activity in
                if activity.isFailure {
                    failureRows.append(activity)
                    return nil
                }
                return ParsedActivity(
                    title: activity.title,
                    isFailure: activity.isFailure,
                    start: activity.start,
                    attachments: activity.attachments,
                    subActivities: strip(activity.subActivities)
                )
            }
        }
        let rest = strip(activities)
        return ParsedActivity.interleavingFailureRows(
            activities: rest, failureRows: failureRows
        )
    }

    private func removingExpectedFailureRows(
        _ messages: [String],
        from activities: [ParsedActivity]
    ) -> [ParsedActivity] {
        var unclaimed = messages
        func removeClaimed(_ activities: [ParsedActivity]) -> [ParsedActivity] {
            activities.compactMap { activity in
                if let index = unclaimed.firstIndex(of: activity.title) {
                    unclaimed.remove(at: index)
                    return nil
                }
                return ParsedActivity(
                    title: activity.title,
                    isFailure: activity.isFailure,
                    start: activity.start,
                    attachments: activity.attachments,
                    subActivities: removeClaimed(activity.subActivities)
                )
            }
        }
        return removeClaimed(activities)
    }

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
}
