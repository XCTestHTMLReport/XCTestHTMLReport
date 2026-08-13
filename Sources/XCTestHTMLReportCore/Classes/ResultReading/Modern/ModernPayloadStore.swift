//
//  ModernPayloadStore.swift
//  XCTestHTMLReportCore
//
//  `xcresulttool export attachments` exports every attachment in the bundle in
//  a single call, naming each file after its attachment uuid and writing a
//  manifest alongside. That replaces the legacy one-subprocess-per-payload
//  export, and with it the per-id locking the legacy path needs: there is no
//  shared temp path to race on here. Only the one-shot export itself is
//  guarded, so concurrent parsing does not trigger it twice.
//

import Foundation

final class ModernPayloadStore: PayloadProviding {
    // MARK: Lifecycle

    /// `export attachments` writes a full copy of every attachment, including
    /// screen recordings. Without this the temp directory outlives the process
    /// and each run leaks tens of megabytes into NSTemporaryDirectory().
    deinit {
        if let directory = exportDirectory {
            try? FileManager.default.removeItem(at: directory)
        }
    }

    init(client: XCResultToolClient, bundleURL: URL, faultCollector: FaultCollector) {
        self.client = client
        self.faultCollector = faultCollector
        url = bundleURL
        relativeURL = URL(fileURLWithPath: bundleURL.lastPathComponent)
    }

    // MARK: Internal

    /// The bundle directory — `PayloadProviding` exposes it so attachment
    /// downsizing can reconstruct absolute paths from relative ones.
    let url: URL

    /// The manifest name of the exported payload for an attachment uuid, or
    /// nil when the bundle exported nothing under that uuid. The reader uses
    /// it to type attachments whose own filename carries no extension.
    func exportedFileName(uuid: String) -> String? {
        ensureExported()
        lock.lock()
        defer { lock.unlock() }
        return fileNamesByUUID[uuid]
    }

    func exportPayload(reference: String, fileName: String?) -> URL? {
        guard let source = sourceURL(for: reference) else {
            faultCollector.record(.payloadExportFailed, "attachment \(reference)")
            return nil
        }
        let resolved = fileName ?? source.lastPathComponent
        let destination = url.appendingPathComponent(resolved)
        // Destinations are content-addressed (`ParsedAttachment.exportFileName`
        // names them by payload id), so a file already at the destination *is*
        // this payload and the export is idempotent: never remove, never
        // rewrite. The predecessor removed-then-copied, which under Xcode
        // 26.2's shared screen-recording display names raced concurrent
        // exports on one path and intermittently recorded a spurious
        // `.payloadExportFailed` (#449).
        if FileManager.default.fileExists(atPath: destination.path) {
            return relativeURL.appendingPathComponent(resolved)
        }
        do {
            try FileManager.default.copyItem(at: source, to: destination)
            return relativeURL.appendingPathComponent(resolved)
        } catch {
            // A concurrent writer of the same payload can still beat us to the
            // creation; its bytes are our bytes, so losing that race is
            // success, not degradation.
            if FileManager.default.fileExists(atPath: destination.path) {
                return relativeURL.appendingPathComponent(resolved)
            }
            Logger.warning("Can't copy \(source) to \(destination): \(error)")
            faultCollector.record(.payloadExportFailed, "attachment \(reference)")
            return nil
        }
    }

    func exportPayloadData(reference: String) -> Data? {
        guard let source = sourceURL(for: reference) else {
            faultCollector.record(.payloadExportFailed, "attachment \(reference)")
            return nil
        }
        do {
            return try Data(contentsOf: source)
        } catch {
            // An exported file we cannot read is a real failure, not a format
            // limitation, so it earns a fault rather than a silent nil.
            Logger.warning("Can't read exported attachment \(source): \(error)")
            faultCollector.record(.payloadExportFailed, "attachment \(reference)")
            return nil
        }
    }

    func exportLogs(reference: String, fileName: String) -> URL? {
        guard let text = logText(reference: reference) else {
            return nil
        }
        let destination = url.appendingPathComponent(fileName)
        do {
            try? FileManager.default.removeItem(at: destination)
            try text.write(to: destination, atomically: true, encoding: .utf8)
            return relativeURL.appendingPathComponent(fileName)
        } catch {
            // A log we read but could not write is a genuine failure. Without
            // the fault the report ships without it and still exits 0.
            Logger.warning("Can't write log to \(destination): \(error)")
            faultCollector.record(.logExportFailed, "log \(reference)")
            return nil
        }
    }

    func exportLogsData(reference: String) -> Data? {
        logText(reference: reference)?.data(using: .utf8)
    }

    // MARK: Private

    private let client: XCResultToolClient
    private let relativeURL: URL
    private let faultCollector: FaultCollector

    private let lock = NSLock()
    private var exportDirectory: URL?
    private var fileNamesByUUID: [String: String] = [:]
    private var exportAttempted = false

    /// The new format has no `emittedOutput`, so the run log is rendered from
    /// the structured `messages` instead, keeping the legacy indentation shape.
    private static func format(_ section: LogSection, depth: Int = 0) -> String {
        let indent = String(repeating: "\t", count: depth)
        var lines = ["\(indent)-------- \(section.title ?? "") --------"]
        for message in section.messages ?? [] {
            lines.append("\(indent)\(message.title ?? message.shortTitle ?? "")")
        }
        for subsection in section.subsections ?? [] {
            lines.append(format(subsection, depth: depth + 1))
        }
        return lines.joined(separator: "\n")
    }

    private func sourceURL(for uuid: String) -> URL? {
        ensureExported()
        lock.lock()
        defer { lock.unlock() }
        guard let directory = exportDirectory, let name = fileNamesByUUID[uuid] else {
            return nil
        }
        return directory.appendingPathComponent(name)
    }

    private func ensureExported() {
        lock.lock()
        defer { lock.unlock() }
        guard !exportAttempted else {
            return
        }
        exportAttempted = true

        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("xchtmlreport-attachments-\(UUID().uuidString)")
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true
            )
            _ = try client.run([
                "export", "attachments", "--output-path", directory.path,
            ])
            let manifestData = try Data(
                contentsOf: directory.appendingPathComponent("manifest.json")
            )
            let manifest = try JSONDecoder().decode(
                [AttachmentManifestEntry].self, from: manifestData
            )
            exportDirectory = directory
            for entry in manifest {
                for attachment in entry.attachments ?? [] {
                    guard let file = attachment.exportedFileName else {
                        continue
                    }
                    // Files are named "<attachment-uuid>.<ext>"; the uuid is
                    // the join key back to the activities document.
                    fileNamesByUUID[(file as NSString).deletingPathExtension] = file
                }
            }
        } catch {
            Logger.warning("Can't export attachments: \(error)")
            faultCollector.record(.payloadExportFailed, "attachment export")
        }
    }

    private func logText(reference: String) -> String? {
        do {
            let section = try client.json(
                ["get", "log", "--type", reference], as: LogSection.self
            )
            return Self.format(section)
        } catch {
            Logger.warning("Can't get logs (\(reference)): \(error)")
            faultCollector.record(.logExportFailed, "log \(reference)")
            return nil
        }
    }
}
