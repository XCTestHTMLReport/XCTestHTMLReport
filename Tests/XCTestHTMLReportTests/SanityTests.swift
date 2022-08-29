import XCTest
import SwiftSoup

final class SanityTests: XCTestCase {
    
    func testBasicFunctionality() throws {
        let testResultsUrl = try XCTUnwrap(
            Bundle.testBundle
                .url(forResource: "SanityResults", withExtension: "xcresult")
        )
        let (
            status,
            maybeStdOut,
            maybeStdErr
        ) = try xchtmlreportCmd(args: ["-r", testResultsUrl.path])
        XCTAssertEqual(status, 0)
        #if !DEBUG // XCResultKit outputs non-fatals to stderr in debug mode
            XCTAssertEqual((maybeStdErr ?? "").isEmpty, true)
        #endif
        let stdOut = try XCTUnwrap(maybeStdOut)
        let htmlUrl = try XCTUnwrap(urlFromXCHtmlreportStdout(stdOut))

        let htmlString = try String(contentsOf: htmlUrl, encoding: .utf8)
        let parser = try SwiftSoup.parse(htmlString)

        try XCTContext.runActivity(named: "Test header contain the right number of results") { _ in
            let elements = try XCTUnwrap(parser.select("div.tests-header > ul:first-of-type > li"))
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
