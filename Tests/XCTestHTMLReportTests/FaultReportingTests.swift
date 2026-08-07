import XCTest
@testable import XCTestHTMLReportCore

final class FaultReportingTests: XCTestCase {
    func testMissingInvocationRecordIsRecordedAsFault() throws {
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
