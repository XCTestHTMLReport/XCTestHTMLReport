//
//  Status.swift
//  XCTestHTMLReport
//
//  Split out of `Test.swift` by A3b (#439, #460), which made this enum the
//  single mapping between an outcome and the report's own vocabulary for it:
//  `cssClass` names the row class the stylesheet paints, the `data-filter` a
//  pill carries, and — through `RunSummary.Tally` — the bucket the summary
//  legend and the filter row are both rendered from. Adding a case now adds a
//  glyph, a legend row, a pill and a filter, with no list anywhere else to
//  keep in step.
//

import Foundation

/// `CaseIterable` so `StatusCSSClassTests` can assert its table covers every
/// case: a status added without a `cssClass` draws no glyph at all, which is
/// how `.expectedFailure` went unnoticed until #439.
enum Status: String, CaseIterable {
    case unknown = ""
    case failure = "Failure"
    case success = "Success"
    case skipped = "Skipped"
    case mixed = "Mixed"
    case expectedFailure = "Expected Failure"

    init(_ parsed: ParsedStatus) {
        switch parsed {
        case .passed:
            self = .success
        case .failed:
            self = .failure
        case .skipped:
            self = .skipped
        case .expectedFailure:
            // Folded into `.unknown` until #439: with no case of its own an
            // expected failure rendered an empty status class, which the
            // stylesheet draws as a blank cell. Both readers already map
            // xcresult's `Expected Failure` here, so carrying it through
            // diverges neither backend.
            self = .expectedFailure
        case .unknown:
            self = .unknown
        }
    }

    /// The class the stylesheet draws a status glyph from, and — since A3b
    /// (#439, #460) — the value a filter pill carries in `data-filter`, so one
    /// enum is the whole mapping between a status and its rows. Adding a case
    /// therefore adds a pill and a filter, with no list to update elsewhere.
    ///
    /// `.unknown` returns a name rather than the empty string it used to: "no
    /// icon at all" and "an icon meaning we do not know" are different
    /// statements, and only the second is true.
    var cssClass: String {
        switch self {
        case .failure:
            return "failed"
        case .success:
            return "succeeded"
        case .skipped:
            return "skipped"
        case .mixed:
            return "mixed"
        case .expectedFailure:
            return "expected-failure"
        case .unknown:
            return "unknown"
        }
    }
}
