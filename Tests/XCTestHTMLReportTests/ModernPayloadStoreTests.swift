//
//  ModernPayloadStoreTests.swift
//

import XCTest
@testable import XCTestHTMLReportCore

final class ModernPayloadStoreTests: XCTestCase {
    private func store(
        for resource: String,
        collector: FaultCollector = FaultCollector()
    ) throws -> (ModernPayloadStore, URL) {
        let source = try XCTUnwrap(
            Bundle.testBundle.url(forResource: resource, withExtension: "xcresult")
        )
        // Copy: the store writes exported payloads into the bundle directory.
        let copy = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent(source.lastPathComponent)
        try FileManager.default.createDirectory(
            at: copy.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try FileManager.default.copyItem(at: source, to: copy)
        return (
            ModernPayloadStore(
                client: XCResultToolClient(bundleURL: copy),
                bundleURL: copy,
                faultCollector: collector
            ),
            copy
        )
    }

    private func firstAttachmentUUID(in bundle: URL) throws -> String {
        let document = try XCResultToolClient(bundleURL: bundle).json(
            [
                "get", "test-results", "activities",
                "--test-id", "FirstSuite/testAttachHtmlData()",
            ],
            as: TestActivities.self
        )
        return try XCTUnwrap(
            document.testRuns?.first?.activities?
                .compactMap { $0.attachments?.first?.uuid }.first
        )
    }

    func testResolvesExportedFileNameByUUID() throws {
        let (store, bundle) = try store(for: "TestResults")
        let uuid = try firstAttachmentUUID(in: bundle)
        let name = try XCTUnwrap(store.exportedFileName(uuid: uuid))
        XCTAssertTrue(name.hasPrefix(uuid), "Exported file is named after the uuid")
        XCTAssertTrue(name.hasSuffix(".html"))
    }

    func testExportPayloadWritesNonEmptyFileIntoBundle() throws {
        let (store, bundle) = try store(for: "TestResults")
        let uuid = try firstAttachmentUUID(in: bundle)
        let relative = try XCTUnwrap(
            store.exportPayload(reference: uuid, fileName: "attached.html")
        )
        let written = bundle.appendingPathComponent(relative.lastPathComponent)
        let data = try Data(contentsOf: written)
        XCTAssertFalse(data.isEmpty)
        XCTAssertTrue(
            try XCTUnwrap(String(bytes: data, encoding: .utf8))
                .contains("Sample attachment body")
        )
    }

    func testExportPayloadDataReturnsTheBytes() throws {
        let (store, bundle) = try store(for: "TestResults")
        let uuid = try firstAttachmentUUID(in: bundle)
        let data = try XCTUnwrap(store.exportPayloadData(reference: uuid))
        XCTAssertTrue(
            try XCTUnwrap(String(bytes: data, encoding: .utf8))
                .contains("Sample attachment body")
        )
    }

    func testUnknownReferenceReturnsNil() throws {
        let (store, _) = try store(for: "SanityResults")
        XCTAssertNil(store.exportPayload(reference: "not-a-uuid", fileName: nil))
    }

    /// Destinations are content-addressed, so exporting the same payload to
    /// the same name twice — sequentially or from concurrent attachment
    /// builds — must be one file, no rewrite, and above all no fault. The
    /// predecessor removed-then-copied, which raced concurrent exports of
    /// payloads sharing a destination and intermittently recorded a spurious
    /// `.payloadExportFailed` (#449).
    func testExportPayloadIsIdempotentForTheSameDestination() throws {
        let collector = FaultCollector()
        let (store, bundle) = try store(for: "TestResults", collector: collector)
        let uuid = try firstAttachmentUUID(in: bundle)

        let first = try XCTUnwrap(
            store.exportPayload(reference: uuid, fileName: "0~abc=.html")
        )
        let written = bundle.appendingPathComponent(first.lastPathComponent)
        let bytes = try Data(contentsOf: written)

        let second = try XCTUnwrap(
            store.exportPayload(reference: uuid, fileName: "0~abc=.html")
        )
        XCTAssertEqual(first, second)
        XCTAssertEqual(
            try Data(contentsOf: written), bytes,
            "The second export must not rewrite the destination"
        )
        XCTAssertTrue(
            collector.faults.isEmpty,
            "Re-exporting an already-exported payload is success, not degradation"
        )
    }

    func testActionLogExportsNextToTheBundle() throws {
        let (store, bundle) = try store(for: "SanityResults")
        // "action" is the fixed log reference the modern reader emits; the
        // store forwards it to `xcresulttool get log --type action`.
        let relative = try XCTUnwrap(store.exportLogs(reference: "action", fileName: "action.log"))
        let written = bundle.appendingPathComponent(relative.lastPathComponent)
        let text = try String(contentsOf: written, encoding: .utf8)
        XCTAssertFalse(text.isEmpty)
    }
}
