//
//  ProgressReportingTests.swift
//
//  Progress reporting for #237, where a 400 MB bundle took long enough that the
//  reporter assumed the tool had hung. The rules here are git's, verbatim from
//  `man git-push`: progress goes to standard error, on by default only when
//  that stream is a terminal, forced by --progress and silenced by --quiet.
//

import Foundation
import XCTest
@testable import XCTestHTMLReportCore

final class ProgressReportingTests: XCTestCase {
    private var lines: [String] = []

    override func setUp() {
        super.setUp()
        lines = []
        Logger.progressOutput = { [weak self] line in self?.lines.append(line) }
        Logger.progressEnabled = true
    }

    override func tearDown() {
        Logger.resetProgressOutput()
        Logger.progressEnabled = false
        super.tearDown()
    }

    // MARK: - When progress is shown

    /// The default for a piped or redirected run, and the reason existing
    /// scripts and CI logs are unaffected by this feature.
    func testStderrIsNotATerminalSoProgressIsOff() {
        XCTAssertFalse(
            Logger.shouldShowProgress(isTerminal: false, forced: false, quiet: false)
        )
    }

    func testStderrIsATerminalSoProgressIsOn() {
        XCTAssertTrue(
            Logger.shouldShowProgress(isTerminal: true, forced: false, quiet: false)
        )
    }

    func testProgressFlagForcesOutputWhenNotATerminal() {
        XCTAssertTrue(
            Logger.shouldShowProgress(isTerminal: false, forced: true, quiet: false)
        )
    }

    /// --quiet is the last word, so a script can silence a tool it does not
    /// control the other flags of.
    func testQuietOverridesTheProgressFlag() {
        XCTAssertFalse(
            Logger.shouldShowProgress(isTerminal: true, forced: true, quiet: true)
        )
    }

    // MARK: - What a phase emits

    func testDisabledProgressEmitsNothing() {
        Logger.progressEnabled = false

        Logger.beginPhase("Reading Big.xcresult")
        Logger.endPhase()

        XCTAssertEqual(lines, [])
    }

    func testCompletedPhaseReportsItsLabel() throws {
        Logger.beginPhase("Reading Big.xcresult")
        Logger.endPhase()

        XCTAssertEqual(lines.count, 1)
        let line = try XCTUnwrap(lines.first)
        XCTAssertTrue(
            line.contains("Reading Big.xcresult"),
            "expected the phase label, got: \(line)"
        )
    }

    /// The timing is half the point: #237 also asks "what aspects of the
    /// process are slowest?", and a per-phase duration answers that on the
    /// user's own data rather than only in our profiling.
    func testCompletedPhaseReportsElapsedTime() throws {
        Logger.beginPhase("Rendering")
        Logger.endPhase()

        let line = try XCTUnwrap(lines.first)
        XCTAssertNotNil(
            line.range(of: #"[0-9]+\.[0-9]+s"#, options: .regularExpression),
            "expected an elapsed time like 1.2s, got: \(line)"
        )
    }

    /// A phase cannot always name itself up front: the attachment count is only
    /// known once the export manifest has been read.
    func testEndPhaseCanRefineTheLabel() throws {
        Logger.beginPhase("Exporting attachments")
        Logger.endPhase("Exporting 2531 attachments")

        let line = try XCTUnwrap(lines.first)
        XCTAssertTrue(
            line.contains("Exporting 2531 attachments"),
            "expected the refined label, got: \(line)"
        )
        XCTAssertFalse(
            lines.contains { $0.contains("Exporting attachments") && !$0.contains("2531") },
            "the provisional label should not also be emitted"
        )
    }

    /// Attachment export is lazy: it fires during a read, so its phase closes
    /// first and prints first. Indentation is what keeps that legible rather
    /// than looking like the phases ran out of order.
    func testNestedPhasesAreIndentedByDepth() {
        Logger.beginPhase("Reading")
        Logger.beginPhase("Exporting")
        Logger.endPhase()
        Logger.endPhase()

        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(
            lines[0].hasPrefix("  Exporting"),
            "the nested phase should be indented, got: \(lines[0])"
        )
        XCTAssertTrue(
            lines[1].hasPrefix("Reading"),
            "the outer phase should not be indented, got: \(lines[1])"
        )
    }

    func testPhasesAreReportedInOrder() throws {
        Logger.beginPhase("Reading")
        Logger.endPhase()
        Logger.beginPhase("Rendering")
        Logger.endPhase()

        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(try XCTUnwrap(lines.first).contains("Reading"))
        XCTAssertTrue(try XCTUnwrap(lines.last).contains("Rendering"))
    }
}
