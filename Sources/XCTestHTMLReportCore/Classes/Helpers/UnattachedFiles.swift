//
//  UnattachedFiles.swift
//

import Foundation

/// Whether `name` is a file this tool writes into a result bundle's top level.
///
/// Two shapes, and nothing else:
/// - an exported attachment, named after its payload id by
///   `ParsedAttachment.exportFileName` (`0~<base64url>[=padding][.<ext>]`, with
///   `=` only as trailing padding, and including the
///   `.jpeg` that `-z` writes in place of the original);
/// - an exported run log, named after the run's identifier path
///   (`<32 hex digits>.log`).
///
/// Everything else in a bundle belongs to Xcode (`Info.plist`,
/// `database.sqlite3`, the object store under `Data/`) or to someone we do not
/// know about, and is never ours to delete (#220).
func isOwnExportFileName(_ name: String) -> Bool {
    let attachment = #"^0~[A-Za-z0-9_\-]+={0,2}(\.[A-Za-z0-9]+)?\z"#
    let runLog = #"^[0-9a-f]{32}\.log\z"#
    // `\z`, not `$`: ICU's `$` also matches before a final newline.
    return [attachment, runLog].contains {
        name.range(of: $0, options: .regularExpression) != nil
    }
}

/// Deletes this tool's own exports that the report being written does not
/// link, such as the original image left behind by an earlier run without
/// `-z`, and returns how many files it removed.
///
/// Before #220 this deleted every file in the bundle and its `Data/`
/// directory that the report did not link, which included `Info.plist`, the
/// database and Xcode's whole object store: the bundle could no longer be read
/// by Xcode or `xcresulttool`. Only the bundle's top level is looked at now,
/// only regular files are considered, and only names `isOwnExportFileName`
/// recognises can go. The bundle stays readable, and stays about its original
/// size.
func removeUnattachedFiles(runs: [Run]) -> Int {
    let fileManager = FileManager.default
    let referenced = linkedFileNames(runs: runs)

    var bundles: [URL] = []
    for run in runs where !bundles.contains(run.file.url.standardizedFileURL) {
        bundles.append(run.file.url.standardizedFileURL)
    }

    var removedFiles = 0
    for bundle in bundles {
        let contents: [URL]
        do {
            contents = try fileManager.contentsOfDirectory(
                at: bundle,
                includingPropertiesForKeys: [.isRegularFileKey]
            )
        } catch {
            Logger.error("Error while listing \(bundle.path): \(error.localizedDescription)")
            continue
        }
        for fileURL in contents {
            let name = fileURL.lastPathComponent
            guard isOwnExportFileName(name), !referenced.contains(name) else {
                continue
            }
            // Regular files only: never a directory, and never a symlink,
            // whose target may live outside the bundle.
            guard (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]))?
                .isRegularFile == true
            else {
                continue
            }
            do {
                try fileManager.removeItem(at: fileURL)
                removedFiles += 1
            } catch {
                Logger.error("Error while removing \(fileURL.path): \(error.localizedDescription)")
            }
        }
    }
    return removedFiles
}

/// The last path component of every file the report links: exported
/// attachments and run logs.
private func linkedFileNames(runs: [Run]) -> Set<String> {
    var names: Set<String> = []
    for run in runs {
        for attachment in run.allAttachments {
            if case let .url(url) = attachment.content {
                names.insert(url.lastPathComponent)
            }
        }
        if case let RenderingContent.url(url) = run.logContent {
            names.insert(url.lastPathComponent)
        }
    }
    return names
}
