//
//  ModernPayloadStoreTests.swift
//

import XCTest
@testable import XCTestHTMLReportCore

final class ModernPayloadStoreTests: XCTestCase {
    private func store(for resource: String) throws -> (ModernPayloadStore, URL) {
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
                faultCollector: FaultCollector()
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
            String(decoding: data, as: UTF8.self).contains("Sample attachment body")
        )
    }

    func testExportPayloadDataReturnsTheBytes() throws {
        let (store, bundle) = try store(for: "TestResults")
        let uuid = try firstAttachmentUUID(in: bundle)
        let data = try XCTUnwrap(store.exportPayloadData(reference: uuid))
        XCTAssertTrue(
            String(decoding: data, as: UTF8.self).contains("Sample attachment body")
        )
    }

    func testUnknownReferenceReturnsNil() throws {
        let (store, _) = try store(for: "SanityResults")
        XCTAssertNil(store.exportPayload(reference: "not-a-uuid", fileName: nil))
    }

    func testActionLogExportsNextToTheBundle() throws {
        let (store, bundle) = try store(for: "SanityResults")
        // "action" is the fixed log reference the modern reader emits; the
        // store forwards it to `xcresulttool get log --type action`.
        let relative = try XCTUnwrap(store.exportLogs(reference: "action"))
        let written = bundle.appendingPathComponent(relative.lastPathComponent)
        let text = try String(contentsOf: written, encoding: .utf8)
        XCTAssertFalse(text.isEmpty)
    }
}
