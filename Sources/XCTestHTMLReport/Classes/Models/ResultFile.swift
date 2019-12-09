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
    private let url: URL
    private let relativeUrl: URL
    private let file: XCResultFile

    init(url: URL) {
        self.url = url
        self.relativeUrl = URL(fileURLWithPath: url.lastPathComponent)
        self.file = XCResultFile(url: url)
    }

    // MARK: - Public

    func exportPayload(id: String) -> URL? {
        guard let savedURL = file.exportPayload(id: id) else {
            Logger.warning("Can't export payload with id \(id)")
            return nil
        }
        let url = self.url.appendingPathComponent(id)
        let fileManager = FileManager.default
        do {
            try? fileManager.removeItem(at: url)
            try fileManager.moveItem(at: savedURL, to: url)
            return relativeUrl.appendingPathComponent(id)
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
        let url = self.url.appendingPathComponent(id)
        let fileManager = FileManager.default
        do {
            try? fileManager.removeItem(at: url)
            try logSection.emittedOutput?.write(to: url, atomically: true, encoding: .utf8)
            return relativeUrl.appendingPathComponent(id)
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
        return logSection.emittedOutput?.data(using: .utf8)
    }
}

