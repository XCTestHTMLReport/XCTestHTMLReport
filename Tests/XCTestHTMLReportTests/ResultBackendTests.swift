//
//  ResultBackendTests.swift
//

import XCTest
@testable import XCTestHTMLReportCore

final class ResultBackendTests: XCTestCase {
    func testModernAlwaysResolvesToModern() {
        XCTAssertEqual(ResultBackend.modern.resolve(), .use(.modern))
    }

    func testExplicitLegacyIsNeverSilentlySubstituted() {
        // The hazard this guards: if an explicit `legacy` quietly became
        // `modern`, a modern-only host would run the modern reader twice and
        // the differential would report parity against itself.
        switch XCResultToolClient.legacyCapability {
        case .available, .unknown:
            XCTAssertEqual(ResultBackend.legacy.resolve(), .use(.legacy))
        case .unavailable:
            XCTAssertEqual(ResultBackend.legacy.resolve(), .legacyUnavailable)
        }
        // Never modern, on any host.
        XCTAssertNotEqual(ResultBackend.legacy.resolve(), .use(.modern))
    }

    func testAutoNeverResolvesToAuto() {
        XCTAssertNotEqual(ResultBackend.auto.resolve(), .use(.auto))
        XCTAssertNotEqual(ResultBackend.auto.resolve(), .legacyUnavailable)
    }

    func testAutoPrefersLegacyWhileTheToolchainOffersIt() {
        // Conditional on the host toolchain rather than asserted outright, so
        // this keeps passing rather than becoming a time bomb after removal.
        if XCResultToolClient.legacyCapability == .available {
            XCTAssertEqual(ResultBackend.auto.resolve(), .use(.legacy))
        } else {
            XCTAssertEqual(ResultBackend.auto.resolve(), .use(.modern))
        }
    }

    func testBothBackendsProduceAReportForTheSameBundle() throws {
        let url = try XCTUnwrap(
            Bundle.testBundle.url(forResource: "SanityResults", withExtension: "xcresult")
        )
        for backend in [ResultBackend.legacy, .modern] {
            let summary = Summary(
                resultPaths: [url.path],
                renderingMode: .linking,
                downsizeImagesEnabled: false,
                downsizeScaleFactor: 0.5,
                backend: backend
            )
            XCTAssertFalse(
                summary.generatedHtmlReport().isEmpty,
                "\(backend) produced no report"
            )
            // Format limitations must never be recorded as faults; if they
            // were, every modern run would exit 3.
            XCTAssertEqual(summary.faults, [], "\(backend) reported faults")
        }
    }

    func testResultReaderFlagWorksOutOfProcess() throws {
        // Task 12's differential forces each reader through the CLI, so the
        // flag has to work from a separate process via `xchtmlreportCmd`, not
        // only through `Summary.init` in this one.
        let url = try XCTUnwrap(
            Bundle.testBundle.url(forResource: "SanityResults", withExtension: "xcresult")
        )

        func groupCount(reader: String) throws -> Int {
            let outputDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("result-reader-\(reader)-\(UUID().uuidString)")
            try FileManager.default.createDirectory(
                at: outputDir, withIntermediateDirectories: true
            )
            defer { try? FileManager.default.removeItem(at: outputDir) }
            let (status, maybeStdOut, maybeStdErr) = try xchtmlreportCmd(args: [
                url.path, "-o", outputDir.path, "--result-reader", reader,
            ])
            let stdErr = maybeStdErr ?? ""
            XCTAssertEqual(
                status, 0,
                "--result-reader \(reader) exited \(status). stderr:\n\(stdErr)"
            )
            let combined = (maybeStdOut ?? "") + stdErr
            XCTAssertFalse(
                combined.contains("Report is degraded"),
                "\(reader) run was degraded:\n\(combined)"
            )
            let html = try String(
                contentsOf: outputDir.appendingPathComponent("index.html"),
                encoding: .utf8
            )
            return html.components(separatedBy: "test-summary-group").count - 1
        }

        let modernGroups = try groupCount(reader: "modern")
        XCTAssertGreaterThan(modernGroups, 0, "modern rendered no test groups")

        if XCResultToolClient.legacyCapability == .available {
            // Legacy interposes the wrapper levels the modern tree omits, so
            // equal counts mean the flag never reached `Summary` and both runs
            // used one backend.
            XCTAssertNotEqual(
                try groupCount(reader: "legacy"), modernGroups,
                "legacy and modern rendered identical group counts — the flag is not reaching Summary"
            )
        }
    }
}
