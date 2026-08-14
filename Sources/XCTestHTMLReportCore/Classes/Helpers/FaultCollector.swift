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
        /// A run's log reference survived parsing but resolved to no content,
        /// so the report ships without that run's log. The log analogue of
        /// `unresolvedAttachment`, found by `Summary.validate()` for the same
        /// reason (#386). A run carrying no log reference at all is structural
        /// absence, not degradation, and is never flagged.
        case unresolvedLog
        /// The activity tree for a test could not be read, so the test appears
        /// in the report with no activities. A genuine read failure, distinct
        /// from a backend that structurally cannot provide a field.
        case missingActivities
        /// XCResultKit could not produce an attachment's payload, or the
        /// exported file could not be moved into the bundle. The attachment is
        /// missing from the report.
        case payloadExportFailed
        /// XCResultKit could not produce a log section, or it could not be
        /// written next to the report. The log is missing from the report.
        case logExportFailed
        /// An explicit `legacy` reader was requested on a toolchain that no
        /// longer provides the legacy commands. The report was produced with
        /// the modern reader instead, which is a different reader than the
        /// caller asked for.
        case legacyReaderUnavailable
        /// A test target is present in the bundle with no test rows beneath
        /// it: it was planned, it was meant to run, and it produced nothing.
        /// The run stopped early, and the report is missing everything that
        /// target would have contributed (#478). A bundle that carries no
        /// testable for a target at all is structural absence — the usual
        /// result of `-only-testing` — and is never flagged, the same rule
        /// `unresolvedLog` and `unresolvedAttachment` follow.
        case emptyPlannedTestable
        /// A host-application or system failure row, which both formats file
        /// under a group Apple names `System Failures`. Direct evidence the
        /// run did not complete, whatever else survived into the report.
        case systemFailure
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
