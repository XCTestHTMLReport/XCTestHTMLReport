//
//  StubPayloadProvider.swift
//
//  A PayloadProviding whose bytes are constants, so a render driven by it is
//  identical on every machine and every run. This is what lets Layer 2 commit
//  goldens at all: the generated .xcresult fixtures cannot support one.
//

import Foundation
@testable import XCTestHTMLReportCore

struct StubPayloadProvider: PayloadProviding {
    /// A 1x1 opaque PNG, base64 rather than generated so the bytes never
    /// depend on the encoder available on the machine running the test.
    static let onePixelPNG = Data(
        base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ"
            + "AAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
    )!

    static let plainText = Data("synthetic attachment body\n".utf8)

    let url: URL
    let exports: [String: Data]

    init(url: URL = URL(fileURLWithPath: "/synthetic.xcresult"), exports: [String: Data]) {
        self.url = url
        self.exports = exports
    }

    func exportPayload(reference: String, fileName: String?) -> URL? {
        guard exports[reference] != nil else {
            return nil
        }
        return URL(fileURLWithPath: fileName ?? reference, relativeTo: url)
    }

    func exportPayloadData(reference: String) -> Data? {
        exports[reference]
    }

    /// Not exercised by Task 1's tests (only screenshot attachments flow
    /// through `exportPayload`/`exportPayloadData`), but required for
    /// `PayloadProviding` conformance.
    func exportLogs(reference _: String, fileName _: String) -> URL? {
        nil
    }

    func exportLogsData(reference _: String) -> Data? {
        nil
    }
}
