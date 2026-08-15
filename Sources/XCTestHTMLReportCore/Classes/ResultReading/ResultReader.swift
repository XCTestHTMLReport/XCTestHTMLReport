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
    /// The bundle directory. Attachment downsizing reconstructs absolute paths
    /// from it (`Attachment.swift`), so it cannot be provider-private.
    var url: URL { get }

    /// Exports the payload to a file inside the bundle directory and returns a
    /// bundle-relative URL, or `nil` on failure.
    func exportPayload(reference: String, fileName: String?) -> URL?
    func exportPayloadData(reference: String) -> Data?
    /// `reference` is backend-internal (a log ref id on legacy, a `--type`
    /// selector on modern) and never names the file; `fileName` does, and the
    /// caller derives it from backend-neutral data so both backends write the
    /// same name — see `Run.init`.
    func exportLogs(reference: String, fileName: String) -> URL?
    func exportLogsData(reference: String) -> Data?
}

extension PayloadProviding {
    func exportPayloadContent(
        reference: String,
        renderingMode: Summary.RenderingMode,
        fileName: String?
    ) -> RenderingContent {
        switch renderingMode {
        case .inline:
            return exportPayloadData(reference: reference)
                .map(RenderingContent.data) ?? .none
        case .linking:
            return exportPayload(reference: reference, fileName: fileName)
                .map(RenderingContent.url) ?? .none
        }
    }

    // The log has no `exportLogsContent` counterpart to the above (#439, A3b).
    // Both modes now need the log's *text* as well as its rendering content —
    // the Logs view renders the log in the page rather than pointing an iframe
    // at it — and one call returning only the content would leave inline mode
    // exporting the same bytes twice. `Run.init` reads the data once and
    // derives both.
}
