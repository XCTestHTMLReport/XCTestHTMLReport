import XCTest
import NDHpple
import class Foundation.Bundle

final class FunctionalTests: XCTestCase {

    func testExample() throws {

        let (status, maybeStdOut, maybeStdErr) = try xchtmlreportCmd(args: [])

        XCTAssertEqual(status, 64)
        XCTAssertEqual(maybeStdOut?.isEmpty, true)
        let stdErr = try XCTUnwrap(maybeStdErr)
        XCTAssertContains(stdErr, "Error: Bundles must be provided either by args or the -r option")
    }

    func testBasicFunctionality() throws {
        let testResultsUrl = try XCTUnwrap(Bundle.testBundle.url(forResource: "TestResults", withExtension: "xcresult"))
        let (status, maybeStdOut, maybeStdErr) = try xchtmlreportCmd(args: ["-r", testResultsUrl.path])
        XCTAssertEqual(status, 0)
        XCTAssertEqual((maybeStdErr ?? "").isEmpty, true)
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

    }

    static var allTests = [
        ("testExample", testExample),
        ("testBasicFunctionality", testBasicFunctionality),
    ]
}
