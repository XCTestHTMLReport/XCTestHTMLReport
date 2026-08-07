//
//  ResultFile.swift
//  Rainbow
//
//  Created by Pierre Felgines on 04/10/2019.
//

import Foundation
import XCResultKit

/// Wrapper of XCResultFile because XCResultFile do not expose `url` property yet
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

    func exportPayload(id: String, fileName: String?) -> URL? {
        // Distinct attachments can share a single payload ref — screen
        // recordings under `-retry-tests-on-failure` routinely do. XCResultKit
        // exports every caller of an id to the same temp path
        // (`NSTemporaryDirectory()/<id>`), so concurrent exports of one id race
        // on both that temp file and the destination: the first move consumes
        // the temp file and every other caller fails with "the former doesn't
        // exist", yielding a spurious unresolved attachment. Parsing is
        // concurrent (see `Run.swift` and `Test.swift`), so serialize per id.
        // Different ids still export in parallel.
        let lock = payloadLock(for: id)
        lock.lock()
        defer { lock.unlock() }

        guard let savedURL = file.exportPayload(id: id) else {
            Logger.warning("Can't export payload with id \(id)")
            faultCollector.record(.payloadExportFailed, "payload id \(id)")
            return nil
        }

        let fileManager = FileManager.default
        let resolvedName = fileName ?? id
        let destination = url.appendingPathComponent(resolvedName)
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
            faultCollector.record(.payloadExportFailed, "payload id \(id) (\(resolvedName))")
            return nil
        }
    }

    func exportPayloadData(id: String) -> Data? {
        // Same shared temp path as `exportPayload(id:fileName:)`: without this
        // a concurrent export of the same id can truncate the file out from
        // under `Data(contentsOf:)`.
        let lock = payloadLock(for: id)
        lock.lock()
        defer { lock.unlock() }

        guard let savedURL = file.exportPayload(id: id) else {
            Logger.warning("Can't export payload with id \(id)")
            faultCollector.record(.payloadExportFailed, "payload id \(id)")
            return nil
        }
        do {
            return try Data(contentsOf: savedURL)
        } catch {
            Logger.warning("Can't get content of \(savedURL)")
            return nil
        }
    }

    func getInvocationRecord() -> ActionsInvocationRecord? {
        file.getInvocationRecord()
    }

    func getTestPlanRunSummaries(id: String) -> ActionTestPlanRunSummaries? {
        file.getTestPlanRunSummaries(id: id)
    }

    func getActionTestSummary(id: String) -> ActionTestSummary? {
        file.getActionTestSummary(id: id)
    }

    func getCodeCoverage() -> CodeCoverage? {
        file.getCodeCoverage()
    }

    func exportLogs(id: String) -> URL? {
        guard let logSection = file.getLogs(id: id) else {
            Logger.warning("Can't get logs with id \(id)")
            faultCollector.record(.logExportFailed, "log id \(id)")
            return nil
        }
        let fileName = "\(id).log"
        let url = url.appendingPathComponent(fileName)
        let fileManager = FileManager.default
        do {
            try? fileManager.removeItem(at: url)
            try logSection.formatEmittedOutput().write(to: url, atomically: true, encoding: .utf8)
            return relativeUrl.appendingPathComponent(fileName)
        } catch {
            Logger.warning("Can't write output to \(url). \(error.localizedDescription)")
            return nil
        }
    }

    func exportLogsData(id: String) -> Data? {
        guard let logSection = file.getLogs(id: id) else {
            Logger.warning("Can't get logs with id \(id)")
            faultCollector.record(.logExportFailed, "log id \(id)")
            return nil
        }
        return logSection.formatEmittedOutput().data(using: .utf8)
    }

    func exportJson() -> Data? {
        file.exportRecursiveJson()
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

extension ResultFile {
    func exportPayloadContent(
        id: String,
        renderingMode: Summary.RenderingMode,
        fileName: String?
    ) -> RenderingContent {
        switch renderingMode {
        case .inline:
            return exportPayloadData(id: id).map(RenderingContent.data) ?? .none
        case .linking:
            return exportPayload(id: id, fileName: fileName).map(RenderingContent.url) ?? .none
        }
    }

    func exportLogsContent(
        id: String,
        renderingMode: Summary.RenderingMode
    ) -> RenderingContent {
        switch renderingMode {
        case .inline:
            return exportLogsData(id: id).map(RenderingContent.data) ?? .none
        case .linking:
            return exportLogs(id: id).map(RenderingContent.url) ?? .none
        }
    }
}
