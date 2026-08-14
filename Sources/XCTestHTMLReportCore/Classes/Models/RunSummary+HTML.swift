//
//  RunSummary+HTML.swift
//  XCTestHTMLReport
//
//  Rendering for the summary header (#439, A1). Split from `RunSummary.swift`
//  so the derivation — which is the part with rules about what may be read —
//  is not read alongside the string substitution.
//

import Foundation

extension RunSummary: HTML {
    var htmlTemplate: String {
        HTMLTemplates.runSummary
    }

    var htmlPlaceholderValues: [String: String] {
        [
            "N_OF_TESTS": String(tally.total),
            "TESTS_LABEL": tally.total == 1 ? "Test" : "Tests",
            "OVERALL_STATUS_CLASS": Self.iconClass(for: overallStatus),
            "RUN_DURATION": duration.formattedSeconds,
            "DEVICES_LABEL": devices.count == 1 ? "1 device" : "\(devices.count) devices",
            "DONUT": donutHTML,
            "LEGEND": tally.buckets.map(Self.legendRow).joined(),
            "DEVICE_BARS": devices.map(Self.deviceRow).joined(),
            "FAILURE_DIGEST": failureDigestHTML,
        ]
    }

    /// The class the shared icon rules paint the run-wide glyph from. Those
    /// rules are named for the outcome, not for the `Status` case (`.skipped`
    /// draws `.skip`), so the mapping is spelled out rather than reusing
    /// `cssClass`, which names the row classes instead.
    private static func iconClass(for status: Status) -> String {
        switch status {
        case .failure: return "failure"
        case .success: return "success"
        default: return "skip"
        }
    }

    /// "12 passed, 6 failed, 1 skipped" — the device bars' visible caption,
    /// and the only reading of the bar that assistive technology gets, since
    /// the bar itself is `aria-hidden`.
    private static func spokenTally(_ tally: RunSummary.Tally) -> String {
        guard tally.total > 0 else {
            return "No tests"
        }
        return tally.buckets.map(\.spoken).joined(separator: ", ")
    }

    private static func legendRow(_ bucket: Bucket) -> String {
        HTMLTemplates.summaryLegendRow
            .replacingOccurrences(of: "[[STATUS_CLASS]]", with: bucket.status.cssClass)
            .replacingOccurrences(
                of: "[[LABEL]]", with: bucket.label.stringByEscapingXMLChars
            )
            .replacingOccurrences(of: "[[COUNT]]", with: String(bucket.count))
    }

    private static func deviceRow(_ device: DeviceRow) -> String {
        // The OS version is a secondary span rather than being folded into the
        // name, because it is the field that tells two otherwise identical
        // destinations apart in a multi-runtime test plan.
        let name = device.name.stringByEscapingXMLChars
        let label = device.osVersion.isEmpty
            ? name
            : name + " <span class=\"device-row-os\">"
            + device.osVersion.stringByEscapingXMLChars + "</span>"
        return HTMLTemplates.summaryDeviceRow
            .replacingOccurrences(of: "[[DEVICE_LABEL]]", with: label)
            .replacingOccurrences(of: "[[SEGMENTS]]", with: barSegments(device.tally))
            .replacingOccurrences(
                of: "[[DEVICE_TALLY]]",
                with: spokenTally(device.tally).stringByEscapingXMLChars
            )
    }

    /// The bar's rects, in a 0–100 user-space viewBox so a segment's width is
    /// its percentage.
    private static func barSegments(_ tally: Tally) -> String {
        segments(of: tally).map { segment in
            HTMLTemplates.summaryBarSegment
                .replacingOccurrences(of: "[[STATUS_CLASS]]", with: segment.status.cssClass)
                .replacingOccurrences(of: "[[X]]", with: format(segment.start))
                .replacingOccurrences(of: "[[WIDTH]]", with: format(segment.length))
        }.joined()
    }

    /// The ring, as one stroked circle per non-empty bucket.
    ///
    /// `pathLength="100"` rebases the dash units onto the same 0–100 scale the
    /// bar uses, so both readings share one arithmetic and neither needs π.
    /// Each arc is a *stroke*: `stroke-dasharray` draws exactly its own share
    /// and leaves the rest of the circumference as gap, and
    /// `stroke-dashoffset` rotates that dash to where the previous arc ended.
    /// `rotate(-90 …)` starts the run at twelve o'clock, as Xcode's does.
    private var donutHTML: String {
        let arcs = Self.segments(of: tally).map { segment in
            HTMLTemplates.summaryDonutSegment
                .replacingOccurrences(of: "[[STATUS_CLASS]]", with: segment.status.cssClass)
                .replacingOccurrences(of: "[[DASH]]", with: Self.format(segment.length))
                .replacingOccurrences(
                    of: "[[GAP]]", with: Self.format(100 - segment.length)
                )
                .replacingOccurrences(of: "[[OFFSET]]", with: Self.format(-segment.start))
        }.joined()
        return HTMLTemplates.summaryDonut
            .replacingOccurrences(of: "[[SEGMENTS]]", with: arcs)
    }

    private var failureDigestHTML: String {
        guard !failures.isEmpty else {
            // No failures, no card. The digest exists to answer "what broke";
            // an empty one answers nothing and costs a screenful.
            return ""
        }
        let rows = failures.map { failure in
            HTMLTemplates.summaryFailureRow
                .replacingOccurrences(of: "[[UUID]]", with: failure.uuid)
                .replacingOccurrences(
                    of: "[[TEST_NAME]]", with: failure.testName.stringByEscapingXMLChars
                )
                .replacingOccurrences(
                    of: "[[MESSAGE]]", with: failure.message.stringByEscapingXMLChars
                )
                .replacingOccurrences(
                    of: "[[SUITE_NAME]]", with: failure.suiteName.stringByEscapingXMLChars
                )
        }.joined()
        return HTMLTemplates.summaryFailureDigest
            .replacingOccurrences(of: "[[FAILURE_ROWS]]", with: rows)
            .replacingOccurrences(
                of: "[[FAILURES_LABEL]]",
                with: failures.count == 1 ? "1 failure" : "\(failures.count) failures"
            )
    }

    /// One bucket's share of the ring and of the bar: where it starts and how
    /// far it runs, on a 0–100 scale.
    private struct Segment {
        let status: Status
        let start: Double
        let length: Double
    }

    /// Both ends are computed from the running count rather than by
    /// accumulating the lengths, so rounding can neither leave a hairline gap
    /// between two arcs nor let the last one overshoot the circle.
    private static func segments(of tally: Tally) -> [Segment] {
        guard tally.total > 0 else {
            return []
        }
        var result: [Segment] = []
        var consumed = 0
        for bucket in tally.buckets {
            let start = 100 * Double(consumed) / Double(tally.total)
            consumed += bucket.count
            let end = 100 * Double(consumed) / Double(tally.total)
            result.append(Segment(status: bucket.status, start: start, length: end - start))
        }
        return result
    }

    /// Fixed precision, so a render is reproducible byte for byte (#430) and
    /// two backends that agree on the counts agree on the markup.
    ///
    /// Zero is normalised first: the first arc's offset is `-0`, which `%.4f`
    /// writes as `-0.0000`.
    private static func format(_ value: Double) -> String {
        String(format: "%.4f", value == 0 ? 0 : value)
    }
}
