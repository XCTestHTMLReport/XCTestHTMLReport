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

enum XCResultToolError: Error, CustomStringConvertible {
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
}

// MARK: - XCResultToolInvoking

/// Seam for injecting a failing client in tests. `ModernResultReader` degrades
/// rather than aborting when a subcommand fails, so the only way to prove the
/// degradation is reported is to make a subcommand fail on demand.
protocol XCResultToolInvoking {
    func run(_ arguments: [String]) throws -> Data
    func json<T: Decodable>(_ arguments: [String], as type: T.Type) throws -> T
    /// Identifies the bundle in log messages.
    var bundleDescription: String { get }
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

    let bundleURL: URL

    var bundleDescription: String {
        bundleURL.lastPathComponent
    }

    func run(_ arguments: [String]) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["xcresulttool"] + arguments + [
            "--path", bundleURL.path,
            "--schema-version", Self.schemaVersion,
        ]

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
                arguments: arguments,
                status: process.terminationStatus,
                stderr: String(data: errorData, encoding: .utf8) ?? ""
            )
        }
        return outputData
    }

    func json<T: Decodable>(_ arguments: [String], as type: T.Type) throws -> T {
        let data = try run(arguments)
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw XCResultToolError.decodingFailed(arguments: arguments, underlying: error)
        }
    }
}
