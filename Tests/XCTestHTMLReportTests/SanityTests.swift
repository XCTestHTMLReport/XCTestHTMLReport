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

        try XCTContext
            .runActivity(named: "Attachments' reference should use the relative path") { _ in
                let imgTags = try parser.select("img.screenshot, img.screenshot-flow")
                XCTAssertFalse(imgTags.isEmpty())

                try imgTags.forEach { img in
                    let src = try img.attr("src")
                    XCTAssertContains(src, ".xcresult/")
                }

                let spanTags = try parser.select("span.icon.preview-icon")
                XCTAssertFalse(imgTags.isEmpty())

                try spanTags.forEach { span in
                    let onClick = try span.attr("onclick")
                    guard onClick.starts(with: "showText") else {
                        return
                    }

                    let data = try span.attr("data")
                    XCTAssertContains(data, ".xcresult/")
                }
            }
    }
    
}
