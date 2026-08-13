//
//  LegacyResultReaderTests.swift
//

import XCTest
@testable import XCTestHTMLReportCore

final class LegacyResultReaderTests: XCTestCase {
    private func read(_ resource: String) throws -> ParsedResult {
        let url = try XCTUnwrap(
            Bundle.testBundle.url(forResource: resource, withExtension: "xcresult")
        )
        let file = ResultFile(url: url, faultCollector: FaultCollector())
        return try XCTUnwrap(LegacyResultReader(file: file).read())
    }

    private func testCases(in result: ParsedResult) -> [ParsedTestCase] {
        func walk(_ node: ParsedNode) -> [ParsedTestCase] {
            switch node {
            case let .group(group): return group.children.flatMap(walk)
            case let .testCase(testCase): return [testCase]
            }
        }
        return result.runs
            .flatMap(\.testables)
            .flatMap(\.groups)
            .flatMap { $0.children.flatMap(walk) }
    }

    func testRepetitionsMergeIntoOneTestCase() throws {
        let cases = try testCases(in: read("RetryResults"))

        // Legacy emits testRetryOnFailure twice as sibling metadata entries;
        // the reader must merge them into one case with two iterations.
        let retried = try XCTUnwrap(
            cases.first { $0.identifier == "RetryTests/testRetryOnFailure()" }
        )
        XCTAssertEqual(retried.iterations.count, 2)
        XCTAssertEqual(retried.iterations.map(\.iterationNumber), [1, 2])
        XCTAssertEqual(retried.iterations.map(\.status), [.failed, .passed])

        // And a non-repeated test still has exactly one iteration — with no
        // iteration number. Under a retry-enabled plan legacy stamps every
        // summary "iteration 1" even when the policy never fired; the modern
        // format reports nothing for a single run, and a lone number renders
        // nowhere, so the reader drops it and the backends agree by
        // construction. `--json` is where the asymmetry would surface.
        let passed = try XCTUnwrap(
            cases.first { $0.identifier == "RetryTests/testJustPass()" }
        )
        XCTAssertEqual(passed.iterations.count, 1)
        XCTAssertNil(
            passed.iterations[0].iterationNumber,
            "A single execution carries no repetition information"
        )
    }

    func testAttachmentFieldsSurviveTranslation() throws {
        let cases = try testCases(in: read("TestResults"))
        let special = try XCTUnwrap(
            cases.first { $0.identifier == "FirstSuite/testWithSpecialChars()" }
        )

        func allAttachments(_ activities: [ParsedActivity]) -> [ParsedAttachment] {
            activities.flatMap { $0.attachments + allAttachments($0.subActivities) }
        }
        let attachments = allAttachments(special.iterations[0].activities)

        // The user-supplied name is distinct from the generated filename on
        // legacy. Losing that distinction is the modern backend's behaviour,
        // and must not leak into this one.
        let named = try XCTUnwrap(
            attachments.first { $0.name?.hasPrefix("FileName with") == true }
        )
        XCTAssertNotEqual(named.name, named.filename)
        XCTAssertEqual(named.filename?.hasSuffix(".txt"), true)
        // The port carries no UTI; legacy maps down to the extension so both
        // backends type attachments the same way.
        XCTAssertEqual(named.filenameExtension, "txt")
    }

    func testUTIMapsToAnExtensionWhenTheFilenameHasNone() {
        // Screen recordings and other generated attachments always carry an
        // extension, so the UTI fallback needs its own coverage rather than
        // riding on a fixture that never reaches it.
        XCTAssertEqual(
            LegacyResultReader.filenameExtension(
                forUTI: "public.mpeg-4", filename: nil
            ),
            "mp4"
        )
        XCTAssertEqual(
            LegacyResultReader.filenameExtension(
                forUTI: "public.plain-text", filename: nil
            ),
            "txt"
        )
        // Filename wins when both are available.
        XCTAssertEqual(
            LegacyResultReader.filenameExtension(
                forUTI: "public.mpeg-4", filename: "thing.PNG"
            ),
            "png"
        )
        // `public.data` is a raw value of `AttachmentType`, so an
        // extensionless attachment carrying it must keep typing as `.data`
        // rather than degrading to `.unknown` for want of a table entry.
        XCTAssertEqual(
            LegacyResultReader.filenameExtension(forUTI: "public.data", filename: nil),
            "dat"
        )
        XCTAssertNil(
            LegacyResultReader.filenameExtension(forUTI: nil, filename: nil)
        )
    }

    func testStatusMapsIntoTheNeutralEnum() {
        XCTAssertEqual(LegacyResultReader.status("Success"), .passed)
        XCTAssertEqual(LegacyResultReader.status("Failure"), .failed)
        XCTAssertEqual(LegacyResultReader.status("Skipped"), .skipped)
        XCTAssertEqual(
            LegacyResultReader.status("Expected Failure"), .expectedFailure
        )
        XCTAssertEqual(LegacyResultReader.status("something else"), .unknown)
    }

    func testDestinationIsPopulated() throws {
        let run = try XCTUnwrap(try read("SanityResults").runs.first)
        XCTAssertFalse(run.destination.displayName.isEmpty)
        XCTAssertFalse(run.destination.modelName.isEmpty)
        XCTAssertFalse(run.destination.operatingSystemVersion.isEmpty)
    }
}
