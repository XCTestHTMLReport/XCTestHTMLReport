import XCTest
import NDHpple
import class Foundation.Bundle

final class FunctionalTests: XCTestCase {

    func testExample() throws {

        let (status, maybeStdOut, maybeStdErr) = try xchtmlreportCmd(args: [])

        XCTAssertEqual(status, 1)
        XCTAssertEqual(maybeStdErr?.isEmpty, true)
        let stdOut = try XCTUnwrap(maybeStdOut)
        XCTAssertContains(stdOut, "Error: Argument -r is required")
    }

    func testBasicFunctionality() throws {
        let testResultsUrl = try XCTUnwrap(Bundle.testBundle.url(forResource: "TestResults", withExtension: "xcresult"))
        let (status, maybeStdOut, maybeStdErr) = try xchtmlreportCmd(args: ["-r", testResultsUrl.path])
        XCTAssertEqual(status, 0)
        #if !DEBUG // XCResultKit outputs non-fatals to stderr in debug mode
        XCTAssertEqual((maybeStdErr ?? "").isEmpty, true)
        #endif
        let stdOut = try XCTUnwrap(maybeStdOut)
        let htmlUrl = try XCTUnwrap(urlFromXCHtmlreportStdout(stdOut))

        let htmlString = try String(contentsOf: htmlUrl, encoding: .utf8)
        let parser = NDHpple(htmlData: htmlString)

        try XCTContext.runActivity(named: "Test header contain the right number of results") { _ in
            let uls = try XCTUnwrap(parser.peekAtSearch(withQuery: "//div[@class='tests-header']/ul"))
            let texts = uls.children.filter { $0.name == "li" }.compactMap { $0.text }
            XCTAssertEqual(texts[0].intGroupMatch("All \\((\\d+)\\)"), 13)
            XCTAssertEqual(texts[1].intGroupMatch("Passed \\((\\d+)\\)"), 7)
            XCTAssertEqual(texts[2].intGroupMatch("Skipped \\((\\d+)\\)"), 1)
            XCTAssertEqual(texts[3].intGroupMatch("Failed \\((\\d+)\\)"), 5)
        }

        try XCTContext.runActivity(named: "Attachments' reference should use the relative path") { _ in
            let imgTags = parser.search(withQuery: "//img[@class='screenshot']")
                + parser.search(withQuery: "//img[@class='screenshot-flow']")
            XCTAssertFalse(imgTags.isEmpty)

            try imgTags.forEach { img in
                let src = try XCTUnwrap(img.attributes["src"])
                try expectContent(of: src, toStartWith: "TestResults.xcresult")
            }

            let spanTags = parser.search(withQuery: "//span[@class='icon preview-icon']")
            XCTAssertFalse(spanTags.isEmpty)

            try spanTags.forEach { span in
                guard let onClick = span.attributes["onclick"],
                      (onClick["nodeContent"] as? String ?? "").starts(with: "showText")
                else { return }

                let data = try XCTUnwrap(span.attributes["data"])
                try expectContent(of: data, toStartWith: "TestResults.xcresult")
            }

            func expectContent(of node: Node, toStartWith prefix: String) throws {
                let content = try XCTUnwrap(node["nodeContent"] as? String)
                XCTAssertTrue(content.starts(with: prefix))
            }
        }
    }

    static var allTests = [
        ("testExample", testExample),
        ("testBasicFunctionality", testBasicFunctionality),
    ]
}
