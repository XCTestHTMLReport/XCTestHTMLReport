import XCResultKit
import XCTest
@testable import XCTestHTMLReportCore

final class FaultReportingTests: XCTestCase {
    /// Build an `Attachment` through the production initializer from legacy
    /// xcresulttool JSON, the same shape XCResultKit decodes from a bundle.
    private func makeAttachment(json: [String: AnyObject]) throws -> Attachment {
        let actionAttachment = try XCTUnwrap(
            ActionTestAttachment(json),
            "ActionTestAttachment did not parse from test JSON"
        )
        return Attachment(
            attachment: actionAttachment,
            file: ResultFile(
                url: URL(fileURLWithPath: NSTemporaryDirectory() + "/DoesNotExist.xcresult"),
                faultCollector: FaultCollector()
            ),
            renderingMode: .linking,
            downsizeImagesEnabled: false,
            downsizeScaleFactor: 0.25
        )
    }

    private func string(_ value: String) -> [String: AnyObject] {
        ["_type": ["_name": "String"], "_value": value] as [String: AnyObject]
    }

    func testAttachmentWithoutPayloadRefIsNotAResolutionFailure() throws {
        // An attachment can legitimately carry no payload at all. Its content
        // is `.none` by construction, not because an export failed (#387).
        let attachment = try makeAttachment(json: [
            "uniformTypeIdentifier": string("public.png") as AnyObject,
            "lifetime": string("keepAlways") as AnyObject,
            "name": string("Screenshot without payload") as AnyObject,
        ])

        XCTAssertNil(attachment.payloadId)
        XCTAssertFalse(
            attachment.failedToResolve,
            "An attachment that never had a payload must not be reported as degradation"
        )
    }

    func testAttachmentWhosePayloadCannotBeExportedIsAResolutionFailure() throws {
        // The counterpart: a payload existed but exporting it produced
        // nothing. That is genuine degradation and must still be flagged.
        let attachment = try makeAttachment(json: [
            "uniformTypeIdentifier": string("public.png") as AnyObject,
            "lifetime": string("keepAlways") as AnyObject,
            "name": string("Screenshot with unexportable payload") as AnyObject,
            "payloadRef": ["id": string("0~bogus")] as AnyObject,
        ])

        XCTAssertNotNil(attachment.payloadId)
        XCTAssertTrue(
            attachment.failedToResolve,
            "A payload that failed to export must still be reported as degradation"
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
