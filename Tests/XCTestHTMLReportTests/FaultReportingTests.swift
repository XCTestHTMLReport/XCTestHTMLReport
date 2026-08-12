import XCTest
@testable import XCTestHTMLReportCore

final class FaultReportingTests: XCTestCase {
    /// Build an `Attachment` through the production initializer, against a
    /// provider whose bundle does not exist so every export fails.
    private func makeAttachment(
        name: String,
        payloadReference: String?
    ) -> Attachment {
        Attachment(
            attachment: ParsedAttachment(
                name: name,
                filename: nil,
                filenameExtension: "png",
                payloadReference: payloadReference
            ),
            file: ResultFile(
                url: URL(fileURLWithPath: NSTemporaryDirectory() + "/DoesNotExist.xcresult"),
                faultCollector: FaultCollector()
            ),
            renderingMode: .linking,
            downsizeImagesEnabled: false,
            downsizeScaleFactor: 0.25
        )
    }

    func testAttachmentWithoutPayloadRefIsNotAResolutionFailure() {
        // An attachment can legitimately carry no payload at all. Its content
        // is `.none` by construction, not because an export failed (#387).
        let attachment = makeAttachment(
            name: "Screenshot without payload",
            payloadReference: nil
        )

        XCTAssertNil(attachment.payloadId)
        XCTAssertFalse(
            attachment.failedToResolve,
            "An attachment that never had a payload must not be reported as degradation"
        )
    }

    func testAttachmentWhosePayloadCannotBeExportedIsAResolutionFailure() {
        // The counterpart: a payload existed but exporting it produced
        // nothing. That is genuine degradation and must still be flagged.
        let attachment = makeAttachment(
            name: "Screenshot with unexportable payload",
            payloadReference: "0~bogus"
        )

        XCTAssertNotNil(attachment.payloadId)
        XCTAssertTrue(
            attachment.failedToResolve,
            "A payload that failed to export must still be reported as degradation"
        )
    }

    func testLogThatReadsButCannotBeWrittenIsRecordedAsFault() throws {
        // `exportLogs` reads the log out of the bundle and then writes it next
        // to the report. A write failure used to log a warning and return nil
        // without recording anything, shipping a report missing its log with
        // exit 0.
        let source = try XCTUnwrap(
            Bundle.testBundle.url(forResource: "SanityResults", withExtension: "xcresult")
        )
        let scratch = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("xchr-log-fault-\(UUID().uuidString)")
        let bundle = scratch.appendingPathComponent("SanityResults.xcresult")
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: scratch, withIntermediateDirectories: true)
        try fileManager.copyItem(at: source, to: bundle)
        defer {
            try? fileManager.setAttributes(
                [.posixPermissions: 0o755], ofItemAtPath: bundle.path
            )
            try? fileManager.removeItem(at: scratch)
        }

        let collector = FaultCollector()
        let file = ResultFile(url: bundle, faultCollector: collector)
        let parsed = try XCTUnwrap(LegacyResultReader(file: file).read())
        let logReference = try XCTUnwrap(
            parsed.runs.first?.logReference,
            "Fixture is expected to carry a log reference"
        )

        // Reading still works — only the write destination is unwritable.
        try fileManager.setAttributes(
            [.posixPermissions: 0o555], ofItemAtPath: bundle.path
        )

        XCTAssertNil(file.exportLogs(reference: logReference))
        XCTAssertTrue(
            collector.faults.contains { $0.kind == .logExportFailed },
            "A log that reads but cannot be written must be recorded as degradation"
        )
    }

    func testMissingInvocationRecordIsRecordedAsFault() {
        let bogusPath = NSTemporaryDirectory() + "/DoesNotExist.xcresult"
        let collector = FaultCollector()

        let summary = Summary(
            resultPaths: [bogusPath],
            renderingMode: .linking,
            downsizeImagesEnabled: false,
            downsizeScaleFactor: 0.25,
            faultCollector: collector
        )

        XCTAssertFalse(summary.faults.isEmpty)
        XCTAssertTrue(summary.faults.contains { $0.kind == .missingInvocationRecord })
    }

    func testCleanFixtureProducesNoFaults() throws {
        let url = try XCTUnwrap(
            Bundle.testBundle.url(forResource: "SanityResults", withExtension: "xcresult")
        )
        let collector = FaultCollector()

        let summary = Summary(
            resultPaths: [url.path],
            renderingMode: .linking,
            downsizeImagesEnabled: false,
            downsizeScaleFactor: 0.25,
            faultCollector: collector
        )
        _ = summary.generatedHtmlReport()

        XCTAssertEqual(summary.faults, [], "Clean fixture must not produce faults")
    }

    func testValidateFlagsUnresolvedAttachments() throws {
        let url = try XCTUnwrap(
            Bundle.testBundle.url(forResource: "TestResults", withExtension: "xcresult")
        )
        let collector = FaultCollector()

        let summary = Summary(
            resultPaths: [url.path],
            renderingMode: .linking,
            downsizeImagesEnabled: false,
            downsizeScaleFactor: 0.25,
            faultCollector: collector
        )
        summary.validate()

        // Every attachment the model knows about must have resolved to real
        // content. An unresolved one renders as an empty src.
        let unresolved = summary.faults.filter { $0.kind == .unresolvedAttachment }
        XCTAssertEqual(
            unresolved, [],
            "Unresolved attachments: \(unresolved.map(\.detail))"
        )
    }

    func testValidateDoesNotDuplicateOrDisturbExistingFaults() throws {
        let url = try XCTUnwrap(
            Bundle.testBundle.url(forResource: "SanityResults", withExtension: "xcresult")
        )
        let collector = FaultCollector()
        // Seed a non-empty fault set before validating. Without this the
        // assertion below is 0 == 0 on a clean fixture, which passes even if
        // validate()'s dedup is deleted outright.
        collector.record(.payloadExportFailed, "seeded-payload-id")
        collector.record(.unresolvedAttachment, "seeded-attachment.png")

        let summary = Summary(
            resultPaths: [url.path],
            renderingMode: .linking,
            downsizeImagesEnabled: false,
            downsizeScaleFactor: 0.25,
            faultCollector: collector
        )

        summary.validate()
        let afterFirst = summary.faults
        XCTAssertEqual(
            afterFirst.count, 2,
            "validate() must neither drop seeded faults nor invent new ones on a clean fixture"
        )

        summary.validate()

        XCTAssertEqual(
            summary.faults, afterFirst,
            "validate() must not re-record, duplicate, or drop faults on a second call"
        )
    }
}
