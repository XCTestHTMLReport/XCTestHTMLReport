//
//  PayloadExportFaultTests.swift
//
//  The legacy provider's payload-export seam (#388). `FaultReportingTests`
//  covers the model-level post-conditions; these cover the call site that
//  decides whether an export happened at all.
//

import XCTest
@testable import XCTestHTMLReportCore

final class PayloadExportFaultTests: XCTestCase {
    /// A legacy provider over a bundle that does not exist, so every export
    /// fails.
    private func providerOverMissingBundle(_ collector: FaultCollector) -> ResultFile {
        ResultFile(
            url: URL(fileURLWithPath: NSTemporaryDirectory() + "/DoesNotExist.xcresult"),
            faultCollector: collector
        )
    }

    func testInlinePayloadExportFailureIsRecordedAsFault() {
        // `XCResultFile.exportPayload(id:)` hands back its temp path whether
        // or not the export ran, so the old `guard let` never fired and this
        // path returned nil having recorded nothing: an inline render dropped
        // the attachment and still exited 0 (#388).
        let collector = FaultCollector()
        let file = providerOverMissingBundle(collector)

        XCTAssertNil(file.exportPayloadData(reference: "0~bogus"))
        XCTAssertEqual(
            collector.faults.map(\.kind), [.payloadExportFailed],
            "A payload export that produced no bytes must be recorded as degradation"
        )
    }

    func testLinkingPayloadExportFailureIsRecordedOnce() {
        let collector = FaultCollector()
        let file = providerOverMissingBundle(collector)

        XCTAssertNil(file.exportPayload(reference: "0~bogus", fileName: "bogus.png"))
        XCTAssertEqual(
            collector.faults.map(\.kind), [.payloadExportFailed],
            "One failed export is one fault, whichever check catches it"
        )
    }

    func testExportedPayloadIsOnlyAcceptedWhenItHasBytes() throws {
        // The live replacement for the dead nil-guard: an export that produced
        // nothing leaves either no file or an empty one.
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("xchr-export-check-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }

        let empty = directory.appendingPathComponent("empty")
        let populated = directory.appendingPathComponent("populated")
        try Data().write(to: empty)
        try Data("payload".utf8).write(to: populated)

        XCTAssertFalse(
            ResultFile.exportProducedPayload(at: directory.appendingPathComponent("missing"))
        )
        XCTAssertFalse(ResultFile.exportProducedPayload(at: empty))
        XCTAssertTrue(ResultFile.exportProducedPayload(at: populated))
    }

    func testInlineExportDoesNotLeaveItsTempFileBehind() throws {
        // Every export of an id writes to the same shared
        // `NSTemporaryDirectory()/<id>` path, and unlike the linking export
        // this one never moves the file away. Left in place it would satisfy
        // the exists-and-non-empty check on a *later*, failed export of the
        // same id, handing back stale bytes as a success.
        let url = try XCTUnwrap(
            Bundle.testBundle.url(forResource: "TestResults", withExtension: "xcresult")
        )
        let collector = FaultCollector()
        let file = ResultFile(url: url, faultCollector: collector)
        let parsed = try XCTUnwrap(LegacyResultReader(file: file).read())
        let reference = try XCTUnwrap(
            Self.firstPayloadReference(in: parsed),
            "Fixture is expected to carry at least one attachment payload"
        )

        XCTAssertNotNil(file.exportPayloadData(reference: reference))

        let tempPath = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(reference)
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: tempPath.path),
            "The inline export must not leave its temp file behind"
        )
        XCTAssertEqual(collector.faults, [], "A payload that exported is not degradation")
    }

    private static func firstPayloadReference(in result: ParsedResult) -> String? {
        func search(activities: [ParsedActivity]) -> String? {
            for activity in activities {
                if let reference = activity.attachments.compactMap(\.payloadReference).first {
                    return reference
                }
                if let nested = search(activities: activity.subActivities) {
                    return nested
                }
            }
            return nil
        }
        func search(nodes: [ParsedNode]) -> String? {
            for node in nodes {
                switch node {
                case let .group(group):
                    if let found = search(nodes: group.children) {
                        return found
                    }
                case let .testCase(testCase):
                    for iteration in testCase.iterations {
                        if let found = search(activities: iteration.activities) {
                            return found
                        }
                    }
                }
            }
            return nil
        }
        return result.runs
            .flatMap(\.testables)
            .flatMap(\.groups)
            .lazy
            .compactMap { search(nodes: $0.children) }
            .first
    }
}
