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
}
