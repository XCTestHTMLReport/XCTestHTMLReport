//
//  SnapshotSupport.swift
//
//  Golden-file comparison for renders driven by the synthetic fixture.
//
//  Goldens are possible here and impossible for the generated .xcresult
//  fixtures for one reason: the synthetic fixture's inputs are constants, so
//  the render changes only when the code does. Refresh with
//  XCHR_UPDATE_SNAPSHOTS=1, which mirrors the XCHR_BASELINE_DIR idiom rather
//  than inventing a second convention.
//

import XCTest

/// Directory holding committed goldens. Derived from this file's path so it
/// resolves the same whether run from Xcode or `swift test`.
private let snapshotDirectory = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("Snapshots")

func assertSnapshot(
    _ actual: String,
    named name: String,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let url = snapshotDirectory.appendingPathComponent("\(name).html")

    if ProcessInfo.processInfo.environment["XCHR_UPDATE_SNAPSHOTS"] == "1" {
        do {
            try FileManager.default.createDirectory(
                at: snapshotDirectory, withIntermediateDirectories: true
            )
            try actual.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            XCTFail("Could not write golden \(name): \(error)", file: file, line: line)
        }
        return
    }

    guard let expected = try? String(contentsOf: url, encoding: .utf8) else {
        XCTFail(
            "Missing golden \(name).html. Create it with "
                + "XCHR_UPDATE_SNAPSHOTS=1 swift test, then review the diff before committing.",
            file: file, line: line
        )
        return
    }

    if actual != expected {
        // Report the first differing line rather than dumping the whole file:
        // index.html is tens of thousands of lines and an unabridged diff in
        // the test log is unreadable.
        let actualLines = actual.components(separatedBy: "\n")
        let expectedLines = expected.components(separatedBy: "\n")
        let firstDifference = zip(actualLines, expectedLines)
            .enumerated()
            .first { $0.element.0 != $0.element.1 }

        let detail: String
        if let difference = firstDifference {
            detail = """
            First difference at line \(difference.offset + 1):
              expected: \(difference.element.1)
                actual: \(difference.element.0)
            """
        } else {
            detail = "Line counts differ: expected \(expectedLines.count), got \(actualLines.count)"
        }

        XCTFail(
            """
            Snapshot \(name) changed.
            \(detail)
            If intended, refresh with: XCHR_UPDATE_SNAPSHOTS=1 swift test
            """,
            file: file, line: line
        )
    }
}
