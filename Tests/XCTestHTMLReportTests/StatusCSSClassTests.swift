//
//  StatusCSSClassTests.swift
//
//  The one contract between `Status` and the stylesheet. `cssClass` is the
//  only thing that decides which glyph a row draws, and its strings are
//  matched by name in `HTMLTemplates`, so a rename on either side is silent
//  at compile time and invisible in the fixtures that happen not to produce
//  that status — which is precisely how `.expectedFailure` and `.unknown`
//  both shipped as blank cells before #439.
//

import XCTest
@testable import XCTestHTMLReportCore

final class StatusCSSClassTests: XCTestCase {
    /// Every status, its class, and nothing else. `Status` is `CaseIterable`
    /// for the sake of the first assertion: adding a case without a row here
    /// fails the test rather than shipping a row that draws no glyph.
    func testEveryStatusDrawsItsOwnGlyphClass() {
        let classes: [Status: String] = [
            .unknown: "unknown",
            .failure: "failed",
            .success: "succeeded",
            .skipped: "skipped",
            .mixed: "mixed",
            .expectedFailure: "expected-failure",
        ]

        XCTAssertEqual(
            Set(classes.keys), Set(Status.allCases),
            "A status missing from this table draws whatever the stylesheet does with an unknown class"
        )
        for (status, expected) in classes {
            XCTAssertEqual(status.cssClass, expected, "Status.\(status)")
        }
        XCTAssertEqual(
            Set(classes.values).count, classes.count,
            "Two statuses sharing a class draw the same glyph for different outcomes"
        )
    }

    /// `.unknown` used to return `""`, which produced `class=""` on the row
    /// and no icon at all — a report that could not tell an outcome looked
    /// exactly like a report with nothing to say. No fixture reaches this
    /// state any more, so this assertion is the only thing holding it.
    func testUnknownIsNamedRatherThanEmpty() {
        XCTAssertEqual(Status.unknown.cssClass, "unknown")
        XCTAssertEqual(Status(.unknown).cssClass, "unknown", "Via the ParsedStatus bridge too")
        XCTAssertFalse(
            Status.unknown.cssClass.isEmpty,
            "An empty class is 'no icon'; the unknown glyph says 'we do not know'"
        )
    }
}
