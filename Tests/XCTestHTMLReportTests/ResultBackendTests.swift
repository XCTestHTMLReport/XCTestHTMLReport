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

    /// `XCHR_RESULT_READER` is the CI override that drives the forced-modern
    /// job leg: it defaults every `Summary` and the CLI flag, so `swift test`
    /// under it exercises the whole suite on one backend. Unset or garbage
    /// must fall back to `.auto` — an env var has no parser to reject it.
    func testEnvironmentOverrideSelectsTheBackend() {
        let original = ProcessInfo.processInfo.environment["XCHR_RESULT_READER"]
        defer {
            if let original {
                setenv("XCHR_RESULT_READER", original, 1)
            } else {
                unsetenv("XCHR_RESULT_READER")
            }
        }

        setenv("XCHR_RESULT_READER", "modern", 1)
        XCTAssertEqual(ResultBackend.fromEnvironment(), .modern)
        setenv("XCHR_RESULT_READER", "legacy", 1)
        XCTAssertEqual(ResultBackend.fromEnvironment(), .legacy)
        setenv("XCHR_RESULT_READER", "not-a-backend", 1)
        XCTAssertEqual(ResultBackend.fromEnvironment(), .auto)
        unsetenv("XCHR_RESULT_READER")
        XCTAssertEqual(ResultBackend.fromEnvironment(), .auto)
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
        // The legacy arm only where the toolchain can honour it: an explicit
        // `legacy` on a modern-only host records `legacyReaderUnavailable` by
        // design, and on an `unknown` host the legacy commands themselves may
        // fail. Same anti-time-bomb reasoning as
        // `testAutoPrefersLegacyWhileTheToolchainOffersIt`; parity stays fully
        // asserted on every host that has both backends.
        var backends: [ResultBackend] = [.modern]
        if XCResultToolClient.legacyCapability == .available {
            backends.insert(.legacy, at: 0)
        }
        for backend in backends {
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
