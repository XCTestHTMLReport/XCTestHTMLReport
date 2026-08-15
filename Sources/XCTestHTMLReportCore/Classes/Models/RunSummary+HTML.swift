//
//  RunSummary+HTML.swift
//  XCTestHTMLReport
//
//  Rendering for the summary header (#439, A1) and, since A3a, for the device
//  picker the header's device bars became. Split from `RunSummary.swift` so the
//  derivation — which is the part with rules about what may be read — is not
//  read alongside the string substitution.
//
//  Two renderings of one view model, deliberately: the band and the picker
//  state the same runs in the same order, from the same tallies, so they cannot
//  disagree. They are separate strings because they land in different parts of
//  the page — see `pickerHTML`.
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
            "FAILURE_DIGEST": failureDigestHTML,
        ]
    }

    /// The device picker (#439, A3a), rendered separately from the band.
    ///
    /// Separately, because it belongs to a different part of the page: the
    /// band stands down for the Logs view and the picker must not, or reading
    /// a log would mean being unable to choose whose log it is. It is built
    /// here rather than in `RunDestination` because this is the type that
    /// already holds every run's tally, and the bars are half of what an
    /// option says.
    var pickerHTML: String {
        // A one-run report needs no run number and a several-run report can
        // need it badly — see `DeviceRow.ordinal`. Decided once, here, so every
        // option and the collapsed summary agree about whether they carry one.
        let numbered = devices.count > 1
        return HTMLTemplates.devicePicker
            .replacingOccurrences(
                of: "[[CURRENT_DEVICE]]",
                with: devices.first.map { Self.destinationLabel($0, numbered: numbered) }
                    ?? "No device"
            )
            .replacingOccurrences(
                of: "[[DEVICE_OPTIONS]]",
                with: devices.map { Self.deviceOption($0, numbered: numbered) }.joined()
            )
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

    /// "12 passed, 6 failed, 1 skipped" — the caption under a picker option's
    /// bar, and the only reading of that bar assistive technology gets, since
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

    /// One destination's label: the name, then the OS version in a secondary
    /// span rather than folded into it, because the version is the field that
    /// tells two otherwise identical destinations apart in a multi-runtime
    /// test plan.
    ///
    /// Rendered markup, not leaf text — both leaves inside it are escaped
    /// here.
    private static func destinationLabel(_ device: DeviceRow, numbered: Bool) -> String {
        var label = device.name.stringByEscapingXMLChars
        if !device.osVersion.isEmpty {
            label += " <span class=\"device-row-os\">"
                + device.osVersion.stringByEscapingXMLChars + "</span>"
        }
        guard numbered else {
            return label
        }
        // Inside the label rather than beside it, so the collapsed summary —
        // which the script fills from this element's text — carries the run
        // number too. A picker that can only tell two identical destinations
        // apart while it is open is not telling the reader which one they are
        // reading.
        return label + " <span class=\"device-row-run\">Run \(device.ordinal)</span>"
    }

    /// One option in the picker: the run's outcome glyph, its destination, the
    /// proportional bar and the same split in words, then the model.
    ///
    /// The bar is `aria-hidden` for the reason the ring is — the tally beside
    /// it is the accessible reading of the identical fact.
    ///
    /// What the device sidebar showed and this does not is its `Identifier:`
    /// line. Since #430 that line has carried the report's own element handle
    /// — a 32-character digest of the run's path through the report — rather
    /// than the destination's identifier, so it named nothing a reader could
    /// use or match against anything outside the page. The handle is still
    /// there, in `data-device` and in the ids it addresses, where it is
    /// machinery rather than content.
    private static func deviceOption(_ device: DeviceRow, numbered: Bool) -> String {
        HTMLTemplates.deviceOption
            .replacingOccurrences(
                of: "[[DEVICE_LABEL]]", with: destinationLabel(device, numbered: numbered)
            )
            .replacingOccurrences(
                of: "[[DEVICE_STATUS_CLASS]]", with: iconClass(for: device.status)
            )
            .replacingOccurrences(of: "[[SEGMENTS]]", with: barSegments(device.tally))
            .replacingOccurrences(
                of: "[[DEVICE_TALLY]]",
                with: spokenTally(device.tally).stringByEscapingXMLChars
            )
            .replacingOccurrences(
                of: "[[DEVICE_MODEL]]", with: device.model.stringByEscapingXMLChars
            )
            // Last, so a model or a device name that happened to contain the
            // literal text of this placeholder could not be filled by it.
            .replacingOccurrences(of: "[[DEVICE_IDENTIFIER]]", with: device.identifier)
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
