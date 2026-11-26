import Foundation
import SwiftSoup
import XCTest
@testable import XCTestHTMLReportCore

/// #220: `-d` used to delete every file in the bundle and its `Data/`
/// directory that the report did not link — `Info.plist`, `database.sqlite3`
/// and Xcode's whole object store — and still exit 0, leaving a bundle neither
/// Xcode nor `xcresulttool` could open. It now deletes only this tool's own
/// stale exports, and says on every run that it is deprecated.
final class DeleteUnattachedFilesTests: XCTestCase {
    private let fileManager = FileManager.default

    /// Copies `TestResults.xcresult` into a scratch directory removed when the
    /// test ends, so `-d` never touches the shared fixture.
    private func scratchCopyOfTestResults() throws -> URL {
        let fixture = try XCTUnwrap(
            Bundle.testBundle.url(forResource: "TestResults", withExtension: "xcresult"),
            "TestResults.xcresult not found; run ./prepareTestResults.sh"
        )
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("xchr-delete-\(UUID().uuidString)")
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let copy = root.appendingPathComponent("TestResults.xcresult")
        try fileManager.copyItem(at: fixture, to: copy)
        return copy
    }

    /// Every file in the bundle that this tool did not write, by path relative
    /// to the bundle, with its size.
    private func xcodeOwnedFiles(in bundle: URL) throws -> [String: Int] {
        var files: [String: Int] = [:]
        let enumerator = try XCTUnwrap(fileManager.enumerator(
            at: bundle, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey]
        ))
        let prefix = bundle.standardizedFileURL.path + "/"
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values.isRegularFile == true else {
                continue
            }
            let relative = String(url.standardizedFileURL.path.dropFirst(prefix.count))
            let isTopLevel = !relative.contains("/")
            if isTopLevel, isOwnExportFileName(relative) {
                continue
            }
            files[relative] = values.fileSize ?? -1
        }
        return files
    }

    func testDeleteFlagLeavesTheBundleReadable() throws {
        let bundle = try scratchCopyOfTestResults()
        let before = try xcodeOwnedFiles(in: bundle)
        XCTAssertNotNil(before["Info.plist"], "fixture has no Info.plist")
        XCTAssertTrue(
            before.keys.contains { $0.hasPrefix("Data/") },
            "fixture has no Data/ object store"
        )

        // A stale export the report will not link, and a file that is neither
        // ours nor Xcode's: only the first may go.
        let stale = bundle.appendingPathComponent("0~staleExportNotInThisReport==.png")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: stale)
        let foreign = bundle.appendingPathComponent("notes.txt")
        try Data("keep me".utf8).write(to: foreign)

        let (status, stdout, stderr) = try xchtmlreportCmd(args: ["-d", bundle.path])
        XCTAssertEqual(
            status, 0,
            "exited \(status).\nstdout:\n\(stdout ?? "")\nstderr:\n\(stderr ?? "")"
        )

        // Nothing Xcode wrote is deleted or rewritten.
        let after = try xcodeOwnedFiles(in: bundle)
        let missing = Set(before.keys).subtracting(after.keys).sorted()
        XCTAssertEqual(missing, [], "-d deleted files the bundle needs")
        let changed = before.keys.filter { after[$0] != nil && after[$0] != before[$0] }.sorted()
        XCTAssertEqual(changed, [], "-d changed files the bundle needs")
        XCTAssertTrue(
            fileManager.fileExists(atPath: foreign.path),
            "-d deleted a file it does not own"
        )
        XCTAssertFalse(fileManager.fileExists(atPath: stale.path), "-d kept a stale export")

        assertXcresulttoolReads(bundle)
        try assertReportLinksExist(besides: bundle)
    }

    /// `xcresulttool get test-results summary` still opens `bundle`.
    private func assertXcresulttoolReads(
        _ bundle: URL, file: StaticString = #filePath, line: UInt = #line
    ) {
        do {
            let summary = Process()
            summary.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            summary.arguments = [
                "xcresulttool", "get", "test-results", "summary", "--path", bundle.path,
            ]
            summary.standardOutput = FileHandle.nullDevice
            summary.standardError = FileHandle.nullDevice
            try summary.run()
            summary.waitUntilExit()
            XCTAssertEqual(
                summary.terminationStatus, 0,
                "xcresulttool cannot read the bundle after -d", file: file, line: line
            )
        } catch {
            XCTFail("could not run xcresulttool: \(error)", file: file, line: line)
        }
    }

    /// Every bundle file that the report written next to `bundle` links still
    /// exists.
    private func assertReportLinksExist(besides bundle: URL) throws {
        let reportDirectory = bundle.deletingLastPathComponent()
        let html = try String(
            contentsOf: reportDirectory.appendingPathComponent("index.html"), encoding: .utf8
        )
        let document = try SwiftSoup.parse(html)
        let links = try document.select("[src], [data]").array().flatMap { element in
            try ["src", "data"].map { try element.attr($0) }
        }
        .filter { $0.hasPrefix("TestResults.xcresult/") }
        XCTAssertFalse(links.isEmpty, "report links no exported files")
        for link in links {
            let path = reportDirectory
                .appendingPathComponent(link.removingPercentEncoding ?? link).path
            XCTAssertTrue(
                fileManager.fileExists(atPath: path),
                "report links \(link), which -d deleted"
            )
        }
    }

    func testDeleteFlagWarnsThatItIsDeprecated() throws {
        let bundle = try scratchCopyOfTestResults()
        let (status, _, stderr) = try xchtmlreportCmd(args: ["-d", bundle.path])
        XCTAssertEqual(status, 0)
        let stderrText = try XCTUnwrap(stderr)
        XCTAssertTrue(stderrText.contains("deprecated"), "no deprecation warning:\n\(stderrText)")
        XCTAssertTrue(
            stderrText.contains("no longer shrinks"),
            "warning does not say why:\n\(stderrText)"
        )
    }

    func testOwnExportFileNames() {
        let ours = [
            "0~lhLrGXqgLaUsDsCxqH9FbHoy1zWSntpYsu64VGEBv815DRmz0tPc7WvTwoFQiEzDM91AmNBNXmnUpVmZJlq-tA==.png",
            "0~lhLrGXqgLaUsDsCxqH9FbHoy1zWSntpYsu64VGEBv815DRmz0tPc7WvTwoFQiEzDM91AmNBNXmnUpVmZJlq-tA==.jpeg",
            "0~abc_DEF-123==",
            "20264b52b84cb3e65c5ff06be4bb344d.log",
        ]
        for name in ours {
            XCTAssertTrue(isOwnExportFileName(name), name)
        }
        let notOurs = [
            "Info.plist",
            "database.sqlite3",
            "database.sqlite3-wal",
            "Data",
            "data.0~lhLrGXqgLaUsDsCxqH9FbHoy1zWSntpYsu64VGEBv815DRmz0tPc7WvTwoFQiEzDM91AmNBNXmnUpVmZJlq-tA==",
            "refs.0~lhLrGXqgLaUsDsCxqH9FbHoy1zWSntpYsu64VGEBv815DRmz0tPc7WvTwoFQiEzDM91AmNBNXmnUpVmZJlq-tA==",
            "report.junit",
            "Screenshot_0_8D1E1B6C-0000-0000-0000-000000000000.png",
            "20264B52B84CB3E65C5FF06BE4BB344D.log",
            "0~a/b.png",
        ]
        for name in notOurs {
            XCTAssertFalse(isOwnExportFileName(name), name)
        }
    }
}
