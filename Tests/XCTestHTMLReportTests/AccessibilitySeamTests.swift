//
//  AccessibilitySeamTests.swift
//
//  The authority on the report's accessibility is `visual/tests/a11y.spec.ts`,
//  which runs axe-core against a real browser. These are the two rules from it
//  that can be checked on the markup alone, restated here so they hold in the
//  `test` jobs too: `visual` is a separate workflow, and a template can lose an
//  `alt` in a change that never runs a browser.
//

import XCTest
@testable import XCTestHTMLReportCore

final class AccessibilitySeamTests: XCTestCase {
    private func renderedReport() -> String {
        Summary(
            parsedRuns: [SyntheticResult.parsedRun],
            payloads: SyntheticResult.payloads,
            renderingMode: .linking,
            downsizeImagesEnabled: false,
            downsizeScaleFactor: 0.5,
            bundleNames: ["Synthetic"]
        ).generatedHtmlReport()
    }

    /// Every `<tag …>` in the document, as its full source text.
    private func elements(named tag: String, in html: String) throws -> [String] {
        let regex = try NSRegularExpression(pattern: "<\(tag)\\b[^>]*>")
        let range = NSRange(html.startIndex ..< html.endIndex, in: html)
        return regex.matches(in: html, range: range).compactMap { match in
            Range(match.range, in: html).map { String(html[$0]) }
        }
    }

    /// axe-core `image-alt`. An empty `alt=""` counts: it is how a decorative
    /// image declares itself, which is what the two preview placeholders are
    /// until a screenshot is put in them.
    func testEveryImageCarriesAnAltAttribute() throws {
        let images = try elements(named: "img", in: renderedReport())
        XCTAssertFalse(images.isEmpty, "the fixture must render images to be worth checking")

        let missing = images.filter { !$0.contains("alt=") }
        XCTAssertEqual(missing, [], "every <img> needs alt text, even if empty")
    }

    /// axe-core `frame-title`. A frame with no accessible name is announced as
    /// nothing but "frame", so a screen reader user cannot tell the log pane
    /// from the attachment pane.
    func testEveryFrameCarriesATitleAttribute() throws {
        let frames = try elements(named: "iframe", in: renderedReport())
        XCTAssertFalse(frames.isEmpty, "the report must still render its frames")

        let missing = frames.filter { !$0.contains("title=") }
        XCTAssertEqual(missing, [], "every <iframe> needs an accessible name")
    }

    /// axe-core `landmark-one-main`, in the one form that survives outside a
    /// browser: the element has to exist at all.
    func testDocumentHasAMainLandmark() {
        XCTAssertTrue(
            renderedReport().contains("<main"),
            "the report's content needs a main landmark to skip to"
        )
    }
}
