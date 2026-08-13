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

    /// A run's console/test log. Short, fixed, and recognisable so a rendered
    /// page can be asserted to contain it, the same way `onePixelPNG` and
    /// `plainText` back attachment assertions.
    static let logText = Data("Synthetic run log line one\nSynthetic run log line two\n".utf8)

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

    /// Mirrors `exportPayload`: resolves from the same `exports` map keyed by
    /// reference, and — like `exportPayload` — never touches the filesystem.
    /// The returned URL is a stand-in for where the log would be written, not
    /// a promise that anything is there.
    func exportLogs(reference: String, fileName: String) -> URL? {
        guard exports[reference] != nil else {
            return nil
        }
        return URL(fileURLWithPath: fileName, relativeTo: url)
    }

    /// Mirrors `exportPayloadData`.
    func exportLogsData(reference: String) -> Data? {
        exports[reference]
    }
}
