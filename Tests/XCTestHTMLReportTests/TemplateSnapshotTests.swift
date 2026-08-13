//
//  TemplateSnapshotTests.swift
//

import XCTest
@testable import XCTestHTMLReportCore

final class TemplateSnapshotTests: XCTestCase {
    private func summary(renderingMode: Summary.RenderingMode = .linking) -> Summary {
        Summary(
            parsedRuns: [SyntheticResult.parsedRun],
            payloads: SyntheticResult.payloads,
            renderingMode: renderingMode,
            downsizeImagesEnabled: false,
            downsizeScaleFactor: 0.5
        )
    }

    func testIndexPage() {
        assertSnapshot(summary().generatedHtmlReport(), named: "index")
    }

    /// Inline mode base64s every attachment. Covered separately because it is
    /// a different escaping path, and because `--rendering-mode` is the flag
    /// the published demo and the PR artifact both depend on.
    func testIndexPageInlineMode() {
        assertSnapshot(summary(renderingMode: .inline).generatedHtmlReport(), named: "index-inline")
    }
}
