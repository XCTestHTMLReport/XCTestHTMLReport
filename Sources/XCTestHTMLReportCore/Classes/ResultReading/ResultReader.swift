//
//  ResultReader.swift
//  XCTestHTMLReportCore
//

import Foundation

/// Reads one result bundle into the backend-neutral model.
protocol ResultReader {
    func read() -> ParsedResult?
}

/// Resolves the opaque payload references in `ParsedAttachment` to bytes, and
/// the run log reference to text.
protocol PayloadProviding {
    /// Exports the payload to a file inside the bundle directory and returns a
    /// bundle-relative URL, or `nil` on failure.
    func exportPayload(reference: String, fileName: String?) -> URL?
    func exportPayloadData(reference: String) -> Data?
    func exportLogs(reference: String) -> URL?
    func exportLogsData(reference: String) -> Data?
}
