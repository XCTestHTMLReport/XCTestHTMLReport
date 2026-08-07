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
        case missingInvocationRecord
        case unresolvedAttachment
        case payloadExportFailed
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
