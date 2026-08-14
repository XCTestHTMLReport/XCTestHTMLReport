//
//  ResultFile.swift
//  Rainbow
//
//  Created by Pierre Felgines on 04/10/2019.
//

import Foundation
import XCResultKit

/// Wrapper of XCResultFile because XCResultFile do not expose `url` property yet.
///
/// The legacy backend's `PayloadProviding` implementation, and the accessor
/// surface `LegacyResultReader` reads the object graph through. Lives beside
/// the reader because both leave together when Apple removes the legacy
/// commands.
class ResultFile {
    let url: URL
    private let relativeUrl: URL
    private let file: XCResultFile
    let faultCollector: FaultCollector

    private let payloadLockTable = DispatchQueue(label: "com.xchtmlreport.payload-lock-table")
    private var payloadLocks: [String: NSLock] = [:]

    init(url: URL, faultCollector: FaultCollector) {
        self.url = url
        self.faultCollector = faultCollector
        relativeUrl = URL(fileURLWithPath: url.lastPathComponent)
        file = XCResultFile(url: url)
    }

    // MARK: - Public

    func getInvocationRecord() -> ActionsInvocationRecord? {
        file.getInvocationRecord()
    }

    func getTestPlanRunSummaries(id: String) -> ActionTestPlanRunSummaries? {
        file.getTestPlanRunSummaries(id: id)
    }

    func getActionTestSummary(id: String) -> ActionTestSummary? {
        file.getActionTestSummary(id: id)
    }

    /// Whether an export actually produced a payload at `url`.
    ///
    /// `XCResultFile.exportPayload(id:)` returns its temp path unconditionally:
    /// the `xcresulttool export` it wraps is `@discardableResult` and its exit
    /// status is never inspected, so the `URL?` it hands back is not a failure
    /// signal and a bare `guard let` on it was dead code (#388). The file on
    /// disk is the only evidence there is. A failed export leaves nothing
    /// behind, and an attachment with no bytes carries no payload reference at
    /// all (#387) — so an empty file is a failed export, not an empty payload.
    ///
    /// Not private so a test can pin the empty-file arm, which no reachable
    /// input produces.
    static func exportProducedPayload(at url: URL) -> Bool {
        guard
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
            let size = (attributes[.size] as? NSNumber)?.uint64Value
        else {
            return false
        }
        return size > 0
    }

    // MARK: - Private

    /// Lock guarding every export of `id`, created on first use.
    private func payloadLock(for id: String) -> NSLock {
        payloadLockTable.sync {
            if let existing = payloadLocks[id] {
                return existing
            }
            let created = NSLock()
            payloadLocks[id] = created
            return created
        }
    }
}

// MARK: PayloadProviding

extension ResultFile: PayloadProviding {
    func exportPayload(reference: String, fileName: String?) -> URL? {
        // Distinct attachments can share a single payload ref — screen
        // recordings under `-retry-tests-on-failure` routinely do. XCResultKit
        // exports every caller of an id to the same temp path
        // (`NSTemporaryDirectory()/<id>`), so concurrent exports of one id race
        // on both that temp file and the destination: the first move consumes
        // the temp file and every other caller fails with "the former doesn't
        // exist", yielding a spurious unresolved attachment. Parsing is
        // concurrent (see `Run.swift` and `Test.swift`), so serialize per id.
        // Different ids still export in parallel.
        let lock = payloadLock(for: reference)
        lock.lock()
        defer { lock.unlock() }

        let fileManager = FileManager.default
        let resolvedName = fileName ?? reference
        let destination = url.appendingPathComponent(resolvedName)

        guard let savedURL = file.exportPayload(id: reference),
              Self.exportProducedPayload(at: savedURL)
        else {
            // The same belt and braces the move's catch applies below, and for
            // the same race: another exporter of this id can consume the shared
            // temp file before we look at it. Destinations are named after the
            // payload id, so a file already there *is* this payload and our
            // export producing nothing is not a degradation. Without this the
            // check above would turn #449 back into spurious faults.
            if fileManager.fileExists(atPath: destination.path) {
                return relativeUrl.appendingPathComponent(resolvedName)
            }
            Logger.warning("Can't export payload with id \(reference)")
            faultCollector.record(.payloadExportFailed, "payload id \(reference)")
            return nil
        }

        do {
            // Serialized per id above, so nothing can slot a file into the
            // destination between this removal and the move.
            try? fileManager.removeItem(at: destination)
            try fileManager.moveItem(at: savedURL, to: destination)
            return relativeUrl.appendingPathComponent(resolvedName)
        } catch {
            // Belt and braces against any remaining source of contention (a
            // second `xchtmlreport` over the same bundle, for instance): if the
            // payload is sitting at the destination, it was exported, and this
            // move losing the race is not a degradation.
            if fileManager.fileExists(atPath: destination.path) {
                return relativeUrl.appendingPathComponent(resolvedName)
            }
            Logger
                .warning(
                    "Can't move item from \(savedURL) to \(destination). \(error.localizedDescription)"
                )
            faultCollector.record(.payloadExportFailed, "payload id \(reference) (\(resolvedName))")
            return nil
        }
    }

    func exportPayloadData(reference: String) -> Data? {
        // Same shared temp path as `exportPayload(reference:fileName:)`: without
        // this a concurrent export of the same id can truncate the file out
        // from under `Data(contentsOf:)`.
        let lock = payloadLock(for: reference)
        lock.lock()
        defer { lock.unlock() }

        guard let savedURL = file.exportPayload(id: reference),
              Self.exportProducedPayload(at: savedURL)
        else {
            Logger.warning("Can't export payload with id \(reference)")
            faultCollector.record(.payloadExportFailed, "payload id \(reference)")
            return nil
        }
        // Unlike `exportPayload(reference:fileName:)`, which moves the temp
        // file into the bundle, this one only reads it — so every inline
        // export used to leave a full copy behind at
        // `NSTemporaryDirectory()/<id>`, which for screen recordings is tens
        // of megabytes per run. `ModernPayloadStore` cleans up its export
        // directory for the same reason. It also keeps the check above
        // honest: nothing survives to satisfy it on a later, failed export of
        // the same id.
        defer { try? FileManager.default.removeItem(at: savedURL) }
        do {
            return try Data(contentsOf: savedURL)
        } catch {
            // An exported file we cannot read is a real failure, not a format
            // limitation — the same call the modern store already makes
            // (`ModernPayloadStore.exportPayloadData`). Without the fault an
            // inline render drops the attachment and still exits 0.
            Logger.warning("Can't get content of \(savedURL). \(error.localizedDescription)")
            faultCollector.record(.payloadExportFailed, "payload id \(reference)")
            return nil
        }
    }

    func exportLogs(reference: String, fileName: String) -> URL? {
        guard let logSection = file.getLogs(id: reference) else {
            Logger.warning("Can't get logs with id \(reference)")
            faultCollector.record(.logExportFailed, "log id \(reference)")
            return nil
        }
        let url = url.appendingPathComponent(fileName)
        let fileManager = FileManager.default
        do {
            try? fileManager.removeItem(at: url)
            try logSection.formatEmittedOutput().write(to: url, atomically: true, encoding: .utf8)
            return relativeUrl.appendingPathComponent(fileName)
        } catch {
            Logger.warning("Can't write output to \(url). \(error.localizedDescription)")
            // A log that read but failed to write would otherwise ship a
            // report missing it and still exit 0.
            faultCollector.record(.logExportFailed, "log id \(reference)")
            return nil
        }
    }

    func exportLogsData(reference: String) -> Data? {
        guard let logSection = file.getLogs(id: reference) else {
            Logger.warning("Can't get logs with id \(reference)")
            faultCollector.record(.logExportFailed, "log id \(reference)")
            return nil
        }
        return logSection.formatEmittedOutput().data(using: .utf8)
    }
}

// MARK: EmittableOutput

extension ActivityLogUnitTestSection: EmittableOutput {
    /// Recursively collect emitted output from each subsection, adding an additional indent to each
    /// nested log
    /// This is how test steps are formatted in Xcode, including the repeated log lines
    func formatEmittedOutput() -> String {
        "-------- \(title) --------\n" +
            (emittedOutput ?? "") +
            subsections
            .compactMap {
                "\t" + $0.formatEmittedOutput()
                    .split(separator: "\n")
                    .joined(separator: "\n\t")
            }
            .joined(separator: "\n")
    }
}

extension ActivityLogSection: EmittableOutput {
    func formatEmittedOutput() -> String {
        "\(title)\n\n" + subsections
            .compactMap { $0.formatEmittedOutput() }
            .joined(separator: "\n")
    }
}
