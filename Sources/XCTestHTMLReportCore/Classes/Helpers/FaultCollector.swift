//
//  FaultCollector.swift
//  XCTestHTMLReportCore
//
//  Records degradation encountered while assembling a report so the CLI can
//  exit non-zero instead of claiming success on an incomplete report.
//

import Foundation

/// A single instance of report degradation.
public struct Fault: Equatable {
    public enum Kind: String {
        /// A result bundle yielded no invocation record, so none of its runs
        /// are in the report. Usually an unreadable, truncated, or
        /// non-`.xcresult` path.
        case missingInvocationRecord
        /// An attachment survived parsing but resolved to no content, so the
        /// report references it with nothing behind it. Found by
        /// `Summary.validate()` after the model is assembled, which catches
        /// nested decode failures that the call sites below cannot see.
        case unresolvedAttachment
        /// XCResultKit could not produce an attachment's payload, or the
        /// exported file could not be moved into the bundle. The attachment is
        /// missing from the report.
        case payloadExportFailed
        /// XCResultKit could not produce a log section, or it could not be
        /// written next to the report. The log is missing from the report.
        case logExportFailed
    }

    public let kind: Kind
    public let detail: String

    public init(kind: Kind, detail: String) {
        self.kind = kind
        self.detail = detail
    }
}

/// Thread-safe accumulator for `Fault`s.
///
/// Parsing runs concurrently (see `Run.swift` and `Test.swift`), so every
/// mutation is serialized behind a private queue.
public final class FaultCollector {
    private var storage: [Fault] = []
    private let queue = DispatchQueue(label: "com.xchtmlreport.faults")

    public init() {}

    public func record(_ kind: Fault.Kind, _ detail: String) {
        queue.sync { storage.append(Fault(kind: kind, detail: detail)) }
    }

    public var faults: [Fault] {
        queue.sync { storage }
    }

    public var isEmpty: Bool {
        queue.sync { storage.isEmpty }
    }
}
