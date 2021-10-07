//
//  UnattachedFiles.swift
//

import Foundation

func removeUnattachedFiles(runs: [Run]) -> Int {
    let skippedFiles = ["report.junit"]
    let fileManager = FileManager.default
    var removedFiles = 0

    var attachmentPathsLastItem: [String?] = []
    for run in runs {
        attachmentPathsLastItem = attachmentPathsLastItem + run.allAttachments.map { $0.source?.lastPathComponent() }
        if case RenderingContent.url(let url) = run.logContent {
            attachmentPathsLastItem.append(url.lastPathComponent)
        }
    }

    func shouldBeDeleted(fileURL: URL) -> Bool {
        /// Do not delete directories
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDir), isDir.boolValue {
            return false
        }

        let lastPathComponent = fileURL.lastPathComponent

        if attachmentPathsLastItem.contains(lastPathComponent) {
            return false
        }

        if skippedFiles.contains(lastPathComponent) {
            return false
        }

        return true
    }

    func searchFileURLs() throws -> [URL] {
        var urls: [URL] = []
        for run in runs {
            let topContents = try fileManager.contentsOfDirectory(at: run.file.url, includingPropertiesForKeys: nil)
            let dataContents = try fileManager.contentsOfDirectory(at: run.file.url.appendingPathComponent("Data"), includingPropertiesForKeys: nil)
            urls = urls + topContents + dataContents
        }
        return urls
    }

    do {
        for fileURL in try searchFileURLs() {
            if shouldBeDeleted(fileURL: fileURL) {
                try fileManager.removeItem(at: fileURL)
                removedFiles += 1
            }
        }
    } catch {
        Logger.error("Error while removing files \(error.localizedDescription)")
    }
    return removedFiles
}

