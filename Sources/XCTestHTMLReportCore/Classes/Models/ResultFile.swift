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

    init(url: URL) {
        self.url = url
        self.relativeUrl = URL(fileURLWithPath: url.lastPathComponent)
        self.file = XCResultFile(url: url)
    }

    // MARK: - Public

    func exportPayload(id: String, fileName: String?) -> URL? {
        guard let savedURL = file.exportPayload(id: id) else {
            Logger.warning("Can't export payload with id \(id)")
            return nil
        }

        let fileManager = FileManager.default
        do {
            let resolvedName = fileName ?? id
            let url = url.appendingPathComponent(resolvedName)
            try? fileManager.removeItem(at: url)
            try fileManager.moveItem(at: savedURL, to: url)
            return relativeUrl.appendingPathComponent(resolvedName)
        } catch {
            Logger.warning("Can't move item from \(savedURL) to \(url). \(error.localizedDescription)")
            return nil
        }
    }

    func exportPayloadData(id: String) -> Data? {
        guard let savedURL = file.exportPayload(id: id) else {
            Logger.warning("Can't export payload with id \(id)")
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
        return file.getInvocationRecord()
    }

    func getTestPlanRunSummaries(id: String) -> ActionTestPlanRunSummaries? {
        return file.getTestPlanRunSummaries(id: id)
    }

    func getActionTestSummary(id: String) -> ActionTestSummary? {
        return file.getActionTestSummary(id: id)
    }

    func getCodeCoverage() -> CodeCoverage? {
        return file.getCodeCoverage()
    }

    func exportLogs(id: String) -> URL? {
        guard let logSection = file.getLogs(id: id) else {
            Logger.warning("Can't get logss with id \(id)")
            return nil
        }
        let fileName = "\(id).log"
        let url = self.url.appendingPathComponent(fileName)
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
            Logger.warning("Can't get logss with id \(id)")
            return nil
        }
        return logSection.formatEmittedOutput().data(using: .utf8)
    }
}

extension ResultFile {

    func exportPayloadContent(id: String,
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

    func exportLogsContent(id: String,
                           renderingMode: Summary.RenderingMode) -> RenderingContent {
        switch renderingMode {
        case .inline:
            return exportLogsData(id: id).map(RenderingContent.data) ?? .none
        case .linking:
            return exportLogs(id: id).map(RenderingContent.url) ?? .none
        }
    }
}
