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

    func testValidateIsIdempotent() throws {
        let url = try XCTUnwrap(
            Bundle.testBundle.url(forResource: "SanityResults", withExtension: "xcresult")
        )
        let summary = Summary(
            resultPaths: [url.path],
            renderingMode: .linking,
            downsizeImagesEnabled: false,
            downsizeScaleFactor: 0.25
        )

        summary.validate()
        let afterFirst = summary.faults.count
        summary.validate()

        XCTAssertEqual(summary.faults.count, afterFirst, "validate() must not double-record")
    }
}
