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

        XCTAssertNil(file.exportLogs(reference: logReference, fileName: "test.log"))
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

    // MARK: - Run logs (#386)

    /// A summary built entirely from constants, so the only thing that can
    /// leave a run's log empty is the reference failing to resolve.
    ///
    /// `StubPayloadProvider` records no faults of its own, which is the point:
    /// anything a test finds on the collector afterwards came from the
    /// post-condition, not from a call site.
    private func syntheticSummary(
        logReference: String?,
        collector: FaultCollector
    ) -> Summary {
        Summary(
            parsedRuns: [ParsedRun(
                destination: ParsedDestination(
                    displayName: "Synthetic Device",
                    deviceIdentifier: "00000000-0000-0000-0000-000000000000",
                    modelName: "Synthetic Model",
                    operatingSystemVersion: "1.0"
                ),
                logReference: logReference,
                testables: []
            )],
            payloads: SyntheticResult.payloads,
            renderingMode: .linking,
            downsizeImagesEnabled: false,
            downsizeScaleFactor: 0.5,
            faultCollector: collector,
            bundleNames: ["Synthetic"]
        )
    }

    func testRunWithoutLogReferenceIsNotAResolutionFailure() {
        // A run can legitimately carry no log reference at all. Its log
        // content is `.none` by construction, not through degradation — the
        // same rule that keeps a payload-less attachment out of the fault list
        // (#387).
        let collector = FaultCollector()
        let summary = syntheticSummary(logReference: nil, collector: collector)

        summary.validate()

        XCTAssertEqual(
            summary.faults, [],
            "A run that never had a log reference must not be reported as degradation"
        )
    }

    func testRunWhoseLogCannotBeResolvedIsRecordedAsFault() {
        // The counterpart: a reference existed and resolved to nothing, so the
        // report ships without that run's log. Nothing recorded that before
        // #386, and the run exited 0.
        let collector = FaultCollector()
        let summary = syntheticSummary(logReference: "no-such-log", collector: collector)

        XCTAssertEqual(
            collector.faults, [],
            "The provider is expected to fail silently here; otherwise the "
                + "assertion below would not be testing the post-condition"
        )

        summary.validate()

        XCTAssertEqual(
            summary.faults.map(\.kind), [.unresolvedLog],
            "A log reference that resolved to no content must be recorded as degradation"
        )

        let afterFirst = summary.faults
        summary.validate()
        XCTAssertEqual(
            summary.faults, afterFirst,
            "validate() must not re-record the log fault on a second call"
        )
    }

    func testRunWithAResolvableLogIsNotAFault() {
        let collector = FaultCollector()
        let summary = syntheticSummary(
            logReference: SyntheticResult.logReference, collector: collector
        )
        _ = summary.generatedHtmlReport()

        summary.validate()

        XCTAssertEqual(summary.faults, [], "A log that resolved must not be flagged")
    }

    /// Copies `SanityResults.xcresult` and deletes the object its log
    /// reference names, leaving a bundle whose log reference survives parsing
    /// and then resolves to nothing.
    private func makeBundleWithUnreadableLog() throws -> URL {
        let source = try XCTUnwrap(
            Bundle.testBundle.url(forResource: "SanityResults", withExtension: "xcresult")
        )
        let scratch = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("xchr-broken-log-\(UUID().uuidString)")
        let bundle = scratch.appendingPathComponent("SanityResults.xcresult")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: scratch) }
        try FileManager.default.copyItem(at: source, to: bundle)

        let reference = try XCTUnwrap(
            LegacyResultReader(file: ResultFile(url: bundle, faultCollector: FaultCollector()))
                .read()?.runs.first?.logReference,
            "Fixture is expected to carry a log reference"
        )
        // The bundle is a content-addressed store: `Data/data.<id>` holds the
        // object `<id>` names, and both backends resolve the run log through
        // it. Removing it is the reachable stand-in for the decode failure
        // #386 is about.
        try FileManager.default.removeItem(
            at: bundle.appendingPathComponent("Data/data.\(reference)")
        )
        return bundle
    }

    func testUnreadableLogExitsNonZeroIdenticallyOnBothBackends() throws {
        // Constructing the bundle needs the legacy reader to name the log
        // object; skip with the rest of the legacy suite once it is gone.
        if case .legacyUnavailable = ResultBackend.legacy.resolve() {
            throw XCTSkip("Toolchain has no legacy commands; the legacy leg cannot run.")
        }
        let bundle = try makeBundleWithUnreadableLog()

        for reader in ["legacy", "modern"] {
            let (status, stdOut, stdErr) = try xchtmlreportCmd(
                args: ["--result-reader", reader, bundle.path]
            )
            let combined = (stdOut ?? "") + (stdErr ?? "")

            XCTAssertEqual(
                status, 3,
                "\(reader): a report shipped without its run log must not exit 0.\n\(combined)"
            )
            // The cause, whose detail is backend-internal, and the symptom,
            // whose detail is not: both backends name the same run the same
            // way, so structurally equal inputs degrade identically.
            try XCTAssertContains(combined, "logExportFailed")
            try XCTAssertContains(combined, "unresolvedLog: log for run ")
        }
    }
}
