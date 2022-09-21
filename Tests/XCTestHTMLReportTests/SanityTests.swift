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
            downsizeImagesEnabled: false
        )

        let document = try SwiftSoup.parse(summary.html)

        try XCTContext.runActivity(named: "Test header contain the right number of results") { _ in
            let elements = try XCTUnwrap(
                document
                    .select("div.tests-header > ul:first-of-type > li")
            )
            let texts = try elements.eachText()
            XCTAssertEqual(texts.count, 5)
            XCTAssertEqual(texts[0].intGroupMatch("All \\((\\d+)\\)"), 1)
            XCTAssertEqual(texts[1].intGroupMatch("Passed \\((\\d+)\\)"), 1)
            XCTAssertEqual(texts[2].intGroupMatch("Skipped \\((\\d+)\\)"), 0)
            XCTAssertEqual(texts[3].intGroupMatch("Failed \\((\\d+)\\)"), 0)
            XCTAssertEqual(texts[4].intGroupMatch("Mixed \\((\\d+)\\)"), 0)
        }
    }
}
