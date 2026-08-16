//
//  ProgressCliTests.swift
//
//  The end of #237 that only shows up through the real binary: which stream
//  progress lands on, and whether a redirected run stays as quiet as it was
//  before the feature existed. `xchtmlreportCmd` captures through pipes, so
//  stderr is never a terminal here -- which is exactly the case that must stay
//  silent by default.
//

import XCTest

final class ProgressCliTests: XCTestCase {
    private var testResultsUrl: URL? {
        Bundle.testBundle.url(forResource: "TestResults", withExtension: "xcresult")
    }

    /// Every label the reporter can emit. The silence assertions below check
    /// the whole set rather than one sample: a leak through any other phase
    /// would otherwise pass unnoticed, which is the failure mode a negative
    /// test is most prone to.
    private static let progressLabels = [
        "Reading ",
        "Exporting ",
        "Rendering ",
        "Writing report",
        "Wrote ",
    ]

    private func assertNoProgress(
        in output: String?,
        _ stream: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let text = output ?? ""
        for label in Self.progressLabels {
            XCTAssertFalse(
                text.contains(label),
                "progress label \"\(label)\" leaked onto \(stream):\n\(text)",
                file: file,
                line: line
            )
        }
    }

    /// The guarantee for every existing script and CI job: nothing new appears.
    func testRedirectedRunEmitsNoProgress() throws {
        let url = try XCTUnwrap(testResultsUrl)

        let (status, _, stderr) = try xchtmlreportCmd(args: ["-r", url.path])

        XCTAssertEqual(status, 0)
        assertNoProgress(in: stderr, "stderr")
    }

    func testProgressFlagForcesPhaseLinesOntoStderr() throws {
        let url = try XCTUnwrap(testResultsUrl)

        let (status, _, stderr) = try xchtmlreportCmd(args: ["-r", url.path, "--progress"])

        XCTAssertEqual(status, 0)
        let output = try XCTUnwrap(stderr)
        XCTAssertTrue(
            output.contains("Rendering"),
            "expected a rendering phase line, got:\n\(output)"
        )
        XCTAssertNotNil(
            output.range(of: #"[0-9]+\.[0-9]+s"#, options: .regularExpression),
            "expected an elapsed time on the phase line, got:\n\(output)"
        )
    }

    /// The whole reason progress is on stderr: `xchtmlreport ... | xargs open`
    /// has to keep working.
    func testProgressNeverReachesStdout() throws {
        let url = try XCTUnwrap(testResultsUrl)

        let (status, stdout, _) = try xchtmlreportCmd(args: ["-r", url.path, "--progress"])

        XCTAssertEqual(status, 0)
        let output = try XCTUnwrap(stdout)
        assertNoProgress(in: output, "stdout")
        XCTAssertTrue(
            output.contains("index.html"),
            "stdout should still carry the report path, got:\n\(output)"
        )
    }

    func testQuietSilencesEvenForcedProgress() throws {
        let url = try XCTUnwrap(testResultsUrl)

        let (status, _, stderr) = try xchtmlreportCmd(
            args: ["-r", url.path, "--progress", "--quiet"]
        )

        XCTAssertEqual(status, 0)
        assertNoProgress(in: stderr, "stderr")
    }
}
