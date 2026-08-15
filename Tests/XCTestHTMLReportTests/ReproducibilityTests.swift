import class Foundation.Bundle
import SwiftSoup
import XCTest

/// The same bundle rendered twice by the same binary must produce the same
/// bytes (#411).
///
/// Every check here runs the binary in a **separate process** on purpose.
/// Two of the three causes of drift this guards against — `Set` iteration
/// order and `Dictionary` iteration order — are seeded once per process by
/// Swift's hash seed, so rendering twice inside one test process cannot
/// observe them. Only re-running the executable can.
final class ReproducibilityTests: XCTestCase {
    private var testResultsUrl: URL? {
        Bundle.testBundle.url(forResource: "TestResults", withExtension: "xcresult")
    }

    private var retryResultsUrl: URL? {
        Bundle.testBundle.url(forResource: "RetryResults", withExtension: "xcresult")
    }

    private var sanityResultsUrl: URL? {
        Bundle.testBundle.url(forResource: "SanityResults", withExtension: "xcresult")
    }

    /// How many times each bundle is rendered. Identifier drift shows up on
    /// every run, but ordering drift is sampled — a rendering that is stable
    /// four runs out of five needs more than one comparison to catch.
    private let renderCount = 5

    // MARK: - Byte identity

    func testRenderingTheSameBundleTwiceProducesIdenticalBytes() throws {
        let testResultsUrl = try XCTUnwrap(testResultsUrl)
        try assertRendersIdentically(bundles: [testResultsUrl])
    }

    /// `RetryResults` is the interesting bundle: it is the only fixture with a
    /// test case that has several iterations, so it exercises the iteration
    /// identifiers and the per-status counts that the other bundles do not.
    func testRenderingARetriedBundleTwiceProducesIdenticalBytes() throws {
        let retryResultsUrl = try XCTUnwrap(
            retryResultsUrl,
            "RetryResults.xcresult not found, this likely means Xcode < 13.0"
        )
        try assertRendersIdentically(bundles: [retryResultsUrl])
    }

    // MARK: - Uniqueness

    /// Passing one bundle twice is the worst case for content-derived
    /// identifiers: two runs whose device, target, suite, test and iteration
    /// names are byte-for-byte equal. Anything derived from names alone
    /// collides here, and a collision is silent — `getElementById` and
    /// `querySelectorAll(...)[0]` both just return the first match, so the
    /// second device's rows stop responding without anything failing to parse.
    func testIdentifiersStayUniqueWhenOneBundleAppearsTwiceInAReport() throws {
        let document = try parseReportDocument(
            xchtmlreportArgs: ["-o", makeOutputDirectory().path] + collidingBundlePaths()
        )

        let identifiers = try mintedIdentifiers(in: document)
        // Each kind is asserted present rather than assumed: a selector that
        // silently stops matching would turn the uniqueness check below into a
        // check of nothing.
        for kind in IdentifierKind.allCases {
            XCTAssertGreaterThan(
                identifiers[kind]?.count ?? 0, 0,
                "No \(kind.rawValue) identifiers found — this test is vacuous for that kind"
            )
        }
        assertNoDuplicates(in: identifiers.values.flatMap { $0 })

        // Every device handle must address exactly one element *per view*,
        // including the two runs that share a device identifier.
        //
        // Two selectors since A3a (#439), where they were one. The shell used
        // to give a run a single pane holding both its tree and its log, so
        // one `div.run#device_<id>` was the whole of what a device handle
        // addressed. Per-view surface ownership splits that in two, and the
        // split is the fix for a real collision rather than a cost of one:
        // before it, every run rendered `id="logs"`, `id="logs-header"` and
        // `id="logs-iframe"`, so this very fixture — one bundle passed twice,
        // plus a third — emitted each of those ids three times. That went
        // unnoticed because the duplicates were hidden inside an inactive
        // pane; nothing here could see them, because the check only ever
        // looked at the pane. The log slice is now addressed by the same
        // per-run handle the tree is, and both are checked.
        let deviceIdentifiers = try XCTUnwrap(identifiers[.device])
        XCTAssertGreaterThanOrEqual(deviceIdentifiers.count, 2, "Expected at least two runs")
        for deviceIdentifier in deviceIdentifiers {
            for view in ["tests", "logs"] {
                let slices = try document.select("div.run-view#\(view)_\(deviceIdentifier)")
                XCTAssertEqual(
                    slices.count, 1,
                    "selectDevice('\(deviceIdentifier)') must resolve to exactly one "
                        + "\(view) view"
                )
            }
        }

        // Every toggle handle must address the element it is meant to open.
        for handle in try mintedIdentifiers(in: document, kinds: [.testCase, .iteration])
            .values.flatMap({ $0 })
        {
            XCTAssertEqual(
                try document.select("#activities-\(handle), #iterations-\(handle)").count, 1,
                "toggle(this, '\(handle)') must resolve to exactly one element"
            )
        }
    }

    // MARK: - Escaping

    /// These identifiers land in two places at once: an HTML `id` attribute and
    /// a single-quoted JavaScript string literal (`toggle(this, '…')`,
    /// `selectDevice('…')`). Neither is escaped by the templates, so a
    /// derivation that ever embedded a raw test name — Swift test names can
    /// contain quotes, angle brackets and spaces — would break the page.
    func testMintedIdentifiersNeedNoEscapingInHTMLOrJavaScript() throws {
        let document = try parseReportDocument(
            xchtmlreportArgs: ["-o", makeOutputDirectory().path] + collidingBundlePaths()
        )

        let identifiers = try mintedIdentifiers(in: document)
        for kind in IdentifierKind.allCases {
            XCTAssertGreaterThan(
                identifiers[kind]?.count ?? 0, 0,
                "No \(kind.rawValue) identifiers found — this test is vacuous for that kind"
            )
        }

        for identifier in identifiers.values.flatMap({ $0 }) {
            XCTAssertNotNil(
                identifier.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression),
                "Identifier <\(identifier)> contains characters that need escaping"
            )
        }
    }

    // MARK: - Ordering

    /// A test case with mixed iteration results renders its per-status counts
    /// as "1 failed, 1 succeeded". Those counts come out of a dictionary, whose
    /// iteration order Swift seeds per process — so without an explicit sort
    /// this line reorders between runs. Assert the order is canonical
    /// (alphabetical by status class) rather than pinning the counts, which
    /// depend on how the simulator behaved when the fixture was recorded.
    func testMixedIterationCountsAreListedInACanonicalOrder() throws {
        let retryResultsUrl = try XCTUnwrap(
            retryResultsUrl,
            "RetryResults.xcresult not found, this likely means Xcode < 13.0"
        )
        let document = try parseReportDocument(
            xchtmlreportArgs: ["-o", makeOutputDirectory().path, retryResultsUrl.path]
        )

        let mixedRows = try document.select("div.test-summary.mixed > p.list-item")
        XCTAssertGreaterThan(
            mixedRows.count, 0,
            "RetryResults is expected to contain at least one mixed test case"
        )

        for row in mixedRows {
            let text = try row.text()
            let statuses = try statusWords(in: text)
            XCTAssertGreaterThanOrEqual(
                statuses.count, 2,
                "A mixed row lists at least two statuses, got <\(text)>"
            )
            XCTAssertEqual(
                statuses, statuses.sorted(),
                "Status counts must be in a fixed order, got <\(text)>"
            )
        }
    }

    // MARK: - Cross-backend normalizer

    func testNormalizerReplacesIdentifiersAndNothingElse() {
        let input = "id=3f9a1c07b25e48d1a6c3079e5b4d2f88 name=FirstSuite/testTwo()"
        XCTAssertEqual(normalizeIdentifiers(input), "id=ID name=FirstSuite/testTwo()")
    }

    /// The digests are the only thing separating two backends' markup, so a
    /// normalizer that matched nothing would make the Task 12 differential
    /// compare raw identifiers and fail on every run.
    func testNormalizerActuallyMatchesARenderedIdentifier() throws {
        // `renderReport(arguments:)` is #430's helper: it runs the CLI out of
        // process and returns `Data`. There is no in-process `render(_:)`.
        let html = try XCTUnwrap(String(
            bytes: renderReport(arguments: [XCTUnwrap(sanityResultsUrl).path]),
            encoding: .utf8
        ))
        XCTAssertNotEqual(
            normalizeIdentifiers(html), html,
            "Expected at least one IdentifierPath digest in the rendered report"
        )
    }
}

// MARK: - Helpers

/// The kinds of node this project mints an identifier for, and how to find
/// each one's identifier in the rendered page.
enum IdentifierKind: String, CaseIterable {
    case device
    case targetSummary
    case suite
    case testCase
    case iteration

    var selector: String {
        switch self {
        // The header device picker's option (#439, A3a), which is where the
        // sidebar card's `selectDevice(...)` handler moved. The handler shape
        // is unchanged, so `selectDeviceArgument` below still reads it.
        case .device: return "button.device-option"
        case .targetSummary: return "div.summary[id]"
        case .suite: return "div.test-summary-group > p > span.drop-down-icon"
        case .testCase: return "div.test-summary > p.list-item > span.drop-down-icon"
        case .iteration: return "div.iteration > p.list-item > span.drop-down-icon"
        }
    }
}

private extension ReproducibilityTests {
    func assertRendersIdentically(
        bundles: [URL],
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let arguments = bundles.map(\.path)
        let first = try renderReport(arguments: arguments)

        for run in 2 ... renderCount {
            let next = try renderReport(arguments: arguments)
            guard first != next else {
                continue
            }
            XCTFail(
                "Run \(run) differs from run 1: \(describeFirstDifference(first, next))",
                file: file,
                line: line
            )
            return
        }
    }

    /// Renders into a fresh directory each time so no run can read back
    /// anything the previous one left behind.
    func renderReport(arguments: [String]) throws -> Data {
        let outputDirectory = try makeOutputDirectory()
        let (status, maybeStdOut, maybeStdErr) = try xchtmlreportCmd(
            args: ["-o", outputDirectory.path] + arguments
        )
        let stdOut = try XCTUnwrap(maybeStdOut)
        XCTAssertEqual(
            status, 0,
            "xchtmlreport exited \(status).\nstdout:\n\(stdOut)\nstderr:\n\(maybeStdErr ?? "")"
        )
        let htmlUrl = try XCTUnwrap(urlFromXCHtmlreportStdout(stdOut))
        return try Data(contentsOf: htmlUrl)
    }

    func makeOutputDirectory() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("XCHTMLReportReproducibility-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    /// The bundles to render when the point is collisions: one bundle listed
    /// twice (identical device, target, suite and test names across two runs)
    /// plus the retried bundle, which is the only fixture with iterations.
    func collidingBundlePaths() throws -> [String] {
        let testResultsUrl = try XCTUnwrap(testResultsUrl)
        let retryResultsUrl = try XCTUnwrap(
            retryResultsUrl,
            "RetryResults.xcresult not found, this likely means Xcode < 13.0"
        )
        return [testResultsUrl.path, retryResultsUrl.path, testResultsUrl.path]
    }

    /// The identifiers this project mints for the test tree, by the kind of
    /// node they belong to. Activity identifiers are deliberately excluded —
    /// those are read from the bundle rather than minted here.
    func mintedIdentifiers(
        in document: Document,
        kinds: [IdentifierKind] = IdentifierKind.allCases
    ) throws -> [IdentifierKind: [String]] {
        var identifiers = [IdentifierKind: [String]]()
        for kind in kinds {
            let elements = try document.select(kind.selector)
            identifiers[kind] = try elements.map { element in
                switch kind {
                case .targetSummary: return try element.attr("id")
                case .device: return try selectDeviceArgument(of: element)
                default: return try toggleArgument(of: element)
                }
            }
        }
        return identifiers
    }

    /// `onclick="toggle(this, 'abc')"` -> `abc`
    func toggleArgument(of element: Element) throws -> String {
        let onClick = try element.attr("onclick")
        return try XCTUnwrap(
            onClick.groupMatch("toggle\\(this, '([^']*)'\\)"),
            "Could not read a toggle() identifier out of <\(onClick)>"
        )
    }

    /// `onclick="selectDevice('abc', this);"` -> `abc`
    func selectDeviceArgument(of element: Element) throws -> String {
        let onClick = try element.attr("onclick")
        return try XCTUnwrap(
            onClick.groupMatch("selectDevice\\('([^']*)'"),
            "Could not read a selectDevice() identifier out of <\(onClick)>"
        )
    }

    func assertNoDuplicates(
        in identifiers: [String],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let counts = identifiers.reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
        let duplicates = counts.filter { $0.value > 1 }.keys.sorted()
        XCTAssertTrue(
            duplicates.isEmpty,
            "\(duplicates.count) identifier(s) used more than once: \(duplicates.prefix(5))",
            file: file,
            line: line
        )
    }

    /// Pulls the status words out of "testRetryOnFailure() 1 failed, 1 succeeded (0.16s)".
    func statusWords(in text: String) throws -> [String] {
        let pattern = "\\d+ (failed|succeeded|skipped|mixed)"
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(text.startIndex ..< text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            Range(match.range(at: 1), in: text).map { String(text[$0]) }
        }
    }

    func describeFirstDifference(_ lhs: Data, _ rhs: Data) -> String {
        guard lhs.count == rhs.count else {
            return "lengths differ: \(lhs.count) vs \(rhs.count) bytes"
        }
        guard let offset = Array(zip(lhs, rhs)).firstIndex(where: !=) else {
            return "no differing byte found"
        }
        let window = 80
        let start = max(0, offset - window / 2)
        let end = min(lhs.count, offset + window)
        func excerpt(_ data: Data) -> String {
            String(bytes: data[start ..< end], encoding: .utf8) ?? "<not valid UTF-8>"
        }
        return """
        first differing byte at offset \(offset)
          run 1: \(excerpt(lhs))
          run n: \(excerpt(rhs))
        """
    }
}
