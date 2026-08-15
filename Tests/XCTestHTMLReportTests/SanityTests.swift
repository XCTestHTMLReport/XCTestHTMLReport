import SwiftSoup
import XCTest
@testable import XCTestHTMLReportCore

final class SanityTests: XCTestCase {
    var sanityResultsUrl: URL? {
        Bundle.testBundle
            .url(forResource: "SanityResults", withExtension: "xcresult")
    }

    func testBasicFunctionality() throws {
        let testResultsUrl = try XCTUnwrap(sanityResultsUrl)
        let summary = Summary(
            resultPaths: [testResultsUrl.path],
            renderingMode: .linking,
            downsizeImagesEnabled: false,
            downsizeScaleFactor: 0.5
        )

        let document = try SwiftSoup.parse(summary.html)

        try XCTContext.runActivity(named: "Test header contain the right number of results") { _ in
            let elements = try XCTUnwrap(
                document
                    .select("div.view-toolbar .filter-pills > button[role=radio]")
            )
            let texts = try elements.eachText()
            // One passing test, so one outcome and one pill beside "All"
            // (#439, A3b): the row is rendered from the run's tally now, and a
            // bucket the run never filled offers no filter — the rule the
            // summary legend already followed. Three pills reading "(0)" were
            // three controls that could only ever empty the pane.
            XCTAssertEqual(texts, ["All (1)", "Passed (1)"])
        }

        // A single passing test executed once, which is the case the two
        // numbers agree on — and the one that proves the executions figure is
        // not simply the test count with a different word on it, since
        // `CoreTests` holds the disagreeing case.
        try XCTContext.runActivity(named: "States the executions it ran") { _ in
            XCTAssertEqual(
                try document.select("#view-tests .view-toolbar-count").text(),
                "1 execution"
            )
        }
    }
}
