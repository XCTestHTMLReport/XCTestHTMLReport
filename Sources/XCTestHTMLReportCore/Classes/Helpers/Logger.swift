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

    public static func error(_ message: String) {
        print("Error: ".red.bold + message)
    }

    public static func success(_ message: String) {
        print(message.green.bold)
    }

    public static func warning(_ message: String) {
        print("Warning: ".yellow.bold + message)
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
}
