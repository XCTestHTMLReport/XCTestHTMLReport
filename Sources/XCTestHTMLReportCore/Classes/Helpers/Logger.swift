//
//  Logger.swift
//  XCTestHTMLReport
//
//  Created by Titouan van Belle on 27.07.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation
import Rainbow

public enum Logger {
    public static var verbose = false

    // MARK: - Progress

    /// Whether phase progress is emitted at all. The CLI sets this from
    /// `shouldShowProgress`.
    public static var progressEnabled = false

    /// Progress is status rather than output, so it goes to stderr alongside
    /// the diagnostics -- a pipeline reading this tool's stdout, which carries
    /// the path of the generated report, must not be fed it. Overridable so
    /// tests can read back what was emitted.
    static var progressOutput: (String) -> Void = defaultProgressOutput

    private static let defaultProgressOutput: (String) -> Void = { line in
        // Same ordering care as `printToStandardError`: flush stdout first so
        // that under `2>&1` progress interleaves where it actually occurred.
        fflush(stdout)
        fputs(line + "\n", stderr)
    }

    static func resetProgressOutput() {
        progressOutput = defaultProgressOutput
    }

    /// git's rule, verbatim from `man git-push`: "Progress status is reported
    /// on the standard error stream by default when it is attached to a
    /// terminal, unless -q is specified. This flag forces progress status even
    /// if the standard error stream is not directed to a terminal."
    ///
    /// Copying a rule users already know beats inventing one, and it leaves
    /// redirected runs -- scripts, CI logs -- exactly as they were.
    public static func shouldShowProgress(isTerminal: Bool, forced: Bool, quiet: Bool) -> Bool {
        if quiet {
            return false
        }
        return forced || isTerminal
    }

    private static var phases: [(label: String, start: Date)] = []

    public static func beginPhase(_ label: String) {
        guard progressEnabled else {
            return
        }
        phases.append((label, Date()))
    }

    /// - Parameter label: replaces the label given to `beginPhase`. A phase
    ///   cannot always name itself up front -- the attachment count is only
    ///   known once the export manifest has been read -- so the closing call
    ///   gets the last word.
    public static func endPhase(_ label: String? = nil) {
        guard progressEnabled, let phase = phases.popLast() else {
            return
        }
        let elapsed = Date().timeIntervalSince(phase.start)
        progressOutput(progressLine(
            label: label ?? phase.label,
            elapsed: elapsed,
            depth: phases.count
        ))
    }

    /// Deliberately uncoloured. Unlike the rest of this file's output, progress
    /// can be forced into a pipe with --progress, and ANSI escapes in a log
    /// file help nobody.
    /// - Parameter depth: how many phases still enclose this one. Attachment
    ///   export is lazy and fires during a read, so the inner phase closes and
    ///   prints first; indenting it says "part of the phase below" rather than
    ///   letting it read as having run out of order.
    private static func progressLine(
        label: String,
        elapsed: TimeInterval,
        depth: Int
    ) -> String {
        let indent = String(repeating: "  ", count: depth)
        let time = String(format: "%.1fs", elapsed)
        let column = 38
        let padding = max(2, column - indent.count - label.count)
        return indent + label + String(repeating: " ", count: padding) + time
    }

    /// Diagnostics go to stderr so that a pipeline consuming this tool's stdout
    /// — which carries the path of the generated report — is not fed warnings
    /// about the report being degraded. `success`, `step` and `substep` stay on
    /// stdout: they are the tool's output, not its complaints.
    public static func error(_ message: String) {
        printToStandardError("Error: ".red.bold + message)
    }

    public static func success(_ message: String) {
        print(message.green.bold)
    }

    public static func warning(_ message: String) {
        printToStandardError("Warning: ".yellow.bold + message)
    }

    public static func step(_ message: String) {
        if verbose {
            print("\n" + message.bold)
        }
    }

    public static func substep(_ message: String) {
        if verbose {
            print("  ▸ " + message)
        }
    }

    private static func printToStandardError(_ message: String) {
        // `FileHandle.write` is unbuffered while `print`'s stdout is block-buffered
        // when piped, so under `2>&1` these lines would jump ahead of stdout output
        // instead of interleaving where they occurred. It also raises an uncatchable
        // Objective-C exception when the descriptor is closed (e.g. `2>&-`). `fputs`
        // avoids both problems. Flushing stdout first keeps interleaving accurate.
        fflush(stdout)
        fputs(message + "\n", stderr)
    }
}
