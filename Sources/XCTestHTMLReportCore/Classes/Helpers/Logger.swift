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
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }
}
