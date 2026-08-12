//
//  XCResultToolClientTests.swift
//

import XCTest
@testable import XCTestHTMLReportCore

final class XCResultToolClientTests: XCTestCase {
    private struct SummaryProbe: Decodable {
        let totalTestCount: Int
        let title: String
    }

    func testDecodesSummaryDocument() throws {
        let url = try XCTUnwrap(
            Bundle.testBundle.url(forResource: "SanityResults", withExtension: "xcresult")
        )
        let client = XCResultToolClient(bundleURL: url)
        let probe = try client.json(
            ["get", "test-results", "summary"], as: SummaryProbe.self
        )
        XCTAssertEqual(probe.totalTestCount, 1)
        XCTAssertFalse(probe.title.isEmpty)
    }

    func testUnknownSubcommandThrows() throws {
        let url = try XCTUnwrap(
            Bundle.testBundle.url(forResource: "SanityResults", withExtension: "xcresult")
        )
        let client = XCResultToolClient(bundleURL: url)
        XCTAssertThrowsError(
            try client.json(["get", "test-results", "nope"], as: SummaryProbe.self)
        )
    }

    func testLegacyAvailabilityIsDetectable() {
        // Not asserting a value: it is true on today's toolchains and false
        // once Apple removes the legacy commands. Asserting either would make
        // this test a time bomb. Assert only that detection runs.
        _ = XCResultToolClient.legacyCapability
    }
}
