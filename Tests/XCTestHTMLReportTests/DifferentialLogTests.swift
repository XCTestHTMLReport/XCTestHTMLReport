//
//  DifferentialLogTests.swift
//
//  The cross-backend assertion for the exported run log (#480), in an
//  extension rather than in `DifferentialTests` itself: that file was already
//  at its length limit, and this shares its cached inline summaries, which is
//  what keeps a suite dominated by `xcresulttool` subprocess time from
//  growing another six parses.
//

import XCTest
@testable import XCTestHTMLReportCore

extension DifferentialTests {
    /// The run log each backend exports must be the same text.
    ///
    /// Nothing compared it before. `DifferentialTests` holds the rendered HTML
    /// and the attachment bytes, and the log payload is neither: the iframe
    /// `src` is a digest of the run rather than of its content, so it is
    /// byte-identical on both sides whatever the file behind it says. That is
    /// how the legacy backend shipped an 86-byte husk against the modern
    /// backend's 4,853 bytes from one bundle and this suite stayed green
    /// (#480).
    func testExportedRunLogsAreIdenticalAcrossBackends() throws {
        try requireBothBackends()

        func logs(_ summary: Summary) -> [String] {
            summary.runs.map { run in
                guard case let .data(data) = run.logContent else {
                    return ""
                }
                return String(data: data, encoding: .utf8) ?? ""
            }
        }

        for fixture in Self.fixtures {
            // Inline, so the bytes are in hand rather than on disk.
            let legacy = try logs(summaryInline(fixture, .legacy))
            let modern = try logs(summaryInline(fixture, .modern))

            // Assert before zipping, which would otherwise truncate to the
            // shorter side and compare only the runs both produced.
            XCTAssertEqual(
                legacy.count, modern.count,
                "\(fixture): backends disagree on the number of run logs"
            )

            for (index, pair) in zip(legacy, modern).enumerated() {
                let (legacyLog, modernLog) = pair
                // Non-vacuity. Two empty logs compare equal, and so do two
                // logs that are nothing but structure — which is what the
                // husk was, and what a backend losing `messages` again would
                // produce. Every line the fixed format emits is either a
                // `-------- title --------` header or a message, so requiring
                // a non-header line is requiring the content itself.
                let content = legacyLog
                    .split(separator: "\n")
                    .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("--------") }
                XCTAssertFalse(
                    content.isEmpty,
                    "\(fixture) run \(index): the legacy log is section titles "
                        + "and nothing else — the #480 husk, which the equality "
                        + "check below would pass through if both sides lost it"
                )
                XCTAssertEqual(
                    legacyLog, modernLog,
                    "\(fixture) run \(index): exported log content differs "
                        + "between backends (legacy \(legacyLog.utf8.count) bytes, "
                        + "modern \(modernLog.utf8.count) bytes)"
                )
            }
        }
    }
}
