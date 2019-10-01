//
//  Logger.swift
//  XCTestHTMLReport
//
//  Created by Titouan van Belle on 27.07.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation
import Rainbow

struct Logger
{
    static var verbose = false

    static func error(_ message: String)
    {
        print("Error: ".red.bold + message)
    }

    static func success(_ message: String)
    {
        print(message.green.bold)
    }

    static func warning(_ message: String)
    {
        print("Warning: ".yellow.bold + message)
    }

    static func step(_ message: String)
    {
        if verbose {
            print("\n" + message.bold)
        }
    }

    static func substep(_ message: String)
    {
        if verbose {
            print("  ▸ " + message)
        }
    }
}

