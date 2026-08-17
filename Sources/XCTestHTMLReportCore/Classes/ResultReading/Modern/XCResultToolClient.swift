//
//  XCResultToolClient.swift
//  XCTestHTMLReportCore
//
//  Runs `xcrun xcresulttool` and decodes its JSON.
//
//  Every subcommand accepts --schema-version. Pinning it means an Apple schema
//  revision fails loudly here rather than silently mis-decoding into a report
//  that looks fine and is wrong.
//

import Foundation

// MARK: - LegacyCapability

/// Whether this toolchain still offers the `--legacy` commands.
public enum LegacyCapability {
    case available
    case unavailable
    /// The version string did not parse. Not proof of absence.
    case unknown
}

// MARK: - XCResultToolError

enum XCResultToolError: Error, CustomStringConvertible, LocalizedError {
    case executionFailed(arguments: [String], status: Int32, stderr: String)
    case decodingFailed(arguments: [String], underlying: Error)

    // MARK: Internal

    var description: String {
        switch self {
        case let .executionFailed(arguments, status, stderr):
            return "xcresulttool \(arguments.joined(separator: " ")) exited \(status): \(stderr)"
        case let .decodingFailed(arguments, underlying):
            return "Could not decode xcresulttool \(arguments.joined(separator: " ")): \(underlying)"
        }
    }

    /// Faults and log lines surface these through `localizedDescription`,
    /// which without this conformance is the generic "The operation couldn't
    /// be completed" instead of the diagnosis above.
    var errorDescription: String? {
        description
    }
}

// MARK: - XCResultToolInvoking

/// Seam for injecting a failing client in tests. `ModernResultReader` degrades
/// rather than aborting when a subcommand fails, so the only way to prove the
/// degradation is reported is to make a subcommand fail on demand.
protocol XCResultToolInvoking {
    func run(_ arguments: [String]) throws -> Data
    func json<T: Decodable>(_ arguments: [String], as type: T.Type) throws -> T
    /// As `run`, minus the pinned `--schema-version`.
    ///
    /// `get --legacy` does not advertise that flag: the legacy document
    /// carries its own `_type` envelope in place of a versioned schema. Its
    /// only caller is the legacy run-log reader, which the modern backend
    /// never reaches.
    func runUnversioned(_ arguments: [String]) throws -> Data
    /// Identifies the bundle in log messages.
    var bundleDescription: String { get }
}

extension XCResultToolInvoking {
    /// Test fakes answer from a fixture table and have no opinion about which
    /// flags the real client would append, so they inherit this rather than
    /// each restating it.
    func runUnversioned(_ arguments: [String]) throws -> Data {
        try run(arguments)
    }

    func jsonUnversioned<T: Decodable>(_ arguments: [String], as type: T.Type) throws -> T {
        try decoded(runUnversioned(arguments), reporting: arguments, as: type)
    }
}

/// Decodes what a subcommand answered with, naming the subcommand if it will
/// not decode. Free rather than a protocol extension: `json` and
/// `jsonUnversioned` differ only in which `run` they call, and this is the
/// half they share — no conformer has any business overriding it.
private func decoded<T: Decodable>(
    _ data: Data,
    reporting reported: [String],
    as type: T.Type
) throws -> T {
    do {
        return try JSONDecoder().decode(type, from: data)
    } catch {
        throw XCResultToolError.decodingFailed(arguments: reported, underlying: error)
    }
}

// MARK: - XCResultToolClient

struct XCResultToolClient: XCResultToolInvoking {
    /// The schema this reader was written against. Bump deliberately, with a
    /// differential run, never as a reflex to a decode failure.
    static let schemaVersion = "0.1.0"

    /// Whether this toolchain still offers the `--legacy` commands.
    ///
    /// `xcresulttool version` prints
    /// `... (legacy commands format version: 3.56)` while they exist, and is
    /// expected to drop the parenthetical once they are removed.
    ///
    /// Three outcomes, not two: a version string we cannot parse at all is
    /// `unknown`, which callers must not treat as proof the commands are gone.
    static let legacyCapability: LegacyCapability = {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["xcresulttool", "version"]
        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe
        do {
            try process.run()
        } catch {
            // `.unknown`, not `.unavailable`. A transient failure to spawn
            // `xcrun` is not evidence that the legacy commands are gone, and
            // reporting absence here would silently skip `DifferentialTests` —
            // the migration's only proof — on a machine where both backends
            // actually work.
            return .unknown
        }
        // Drain stderr too. An undrained pipe that fills blocks the child in
        // write() forever, and this probe runs before anything else works.
        let errorDrained = DispatchGroup()
        errorDrained.enter()
        DispatchQueue.global().async {
            _ = errorPipe.fileHandleForReading.readDataToEndOfFile()
            errorDrained.leave()
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        errorDrained.wait()
        process.waitUntilExit()
        let text = String(data: data, encoding: .utf8) ?? ""
        guard process.terminationStatus == 0, text.contains("xcresulttool version") else {
            // Did not look like a version string at all — say so rather than
            // reporting absence we have not established.
            return .unknown
        }
        return text.contains("legacy commands format version") ? .available : .unavailable
    }()

    /// Where `xcresulttool` lives, resolved once per process.
    ///
    /// `xcrun` is a resolver: it locates the tool for the selected developer
    /// directory, then execs it. Doing that per query spawns an entire extra
    /// process — ~7 ms against ~28 ms for the query itself — and the answer
    /// cannot change within a run, so it is paid for once here instead of once
    /// per test case. Resolution still goes through `xcrun --find`, so
    /// `xcode-select` and `DEVELOPER_DIR` continue to choose the toolchain.
    ///
    /// `nil` when resolution fails, which is not an error: see `invocation`.
    static let resolvedTool: URL? = {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["--find", "xcresulttool"]
        let out = Pipe()
        process.standardOutput = out
        // Null rather than a pipe: nothing reads it, and an undrained pipe
        // that fills would block the child forever.
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return nil
        }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            return nil
        }
        let path = (String(data: data, encoding: .utf8) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) else {
            return nil
        }
        return URL(fileURLWithPath: path)
    }()

    let bundleURL: URL

    var bundleDescription: String {
        bundleURL.lastPathComponent
    }

    /// How to spawn the tool, given what resolution found.
    ///
    /// Unresolvable is a degradation, not a failure: a machine with no Xcode
    /// selected, or a Command Line Tools-only install, still works through the
    /// original `xcrun` route — just a process slower per query. Pure, so both
    /// branches are provable without spawning anything.
    static func invocation(
        resolvedTool: URL?
    ) -> (executable: URL, leadingArguments: [String]) {
        guard let resolvedTool else {
            return (URL(fileURLWithPath: "/usr/bin/xcrun"), ["xcresulttool"])
        }
        return (resolvedTool, [])
    }

    func run(_ arguments: [String]) throws -> Data {
        try execute(
            arguments + ["--path", bundleURL.path, "--schema-version", Self.schemaVersion],
            reporting: arguments
        )
    }

    func runUnversioned(_ arguments: [String]) throws -> Data {
        try execute(arguments + ["--path", bundleURL.path], reporting: arguments)
    }

    func json<T: Decodable>(_ arguments: [String], as type: T.Type) throws -> T {
        try decoded(run(arguments), reporting: arguments, as: type)
    }

    // MARK: Private

    /// `reporting` is what a failure names, so the diagnosis quotes the
    /// subcommand the caller asked for rather than the path and version flags
    /// appended above.
    private func execute(_ arguments: [String], reporting reported: [String]) throws -> Data {
        let invocation = Self.invocation(resolvedTool: Self.resolvedTool)
        let process = Process()
        process.executableURL = invocation.executable
        process.arguments = invocation.leadingArguments + arguments

        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        try process.run()

        // Drain before waiting: xcresulttool output routinely outgrows the
        // pipe buffer, and waiting first deadlocks when it does.
        var errorData = Data()
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global().async {
            errorData = err.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        let outputData = out.fileHandleForReading.readDataToEndOfFile()
        group.wait()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw XCResultToolError.executionFailed(
                arguments: reported,
                status: process.terminationStatus,
                stderr: String(data: errorData, encoding: .utf8) ?? ""
            )
        }
        return outputData
    }
}
