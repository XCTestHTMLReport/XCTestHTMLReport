//
//  Command.swift
//  XCTestHTMLReport
//
//  Created by Titouan van Belle on 27.07.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation

struct Command
{
    var arguments: [Argument]!

    var isValid: Bool {
        let flagIndexes = CommandLine.arguments.dropFirst().map { $0.first == "-" ? CommandLine.arguments.index(of: $0) : nil }.flatMap { $0 }

        for index in 0..<arguments.count {
            let argument = arguments[index]
            let argWithDash = "-" + argument.shortFlag

            let argIndex = CommandLine.arguments.index(of: argWithDash)
            if argument.required {
                if argIndex == nil {
                    Logger.error("Argument \(argWithDash) is required")
                    return false
                }
            }

            if let blockArgument = argument as? BlockArgument {
                if argIndex != nil {
                    blockArgument.block()
                }
            } else if let valueArgument = argument as? ValueArgument {
                let valueIndex = argIndex! + 1
                if CommandLine.arguments.count == valueIndex || flagIndexes.contains(valueIndex) {
                    Logger.error("No value was passed for argument \(argWithDash)")
                    return false
                }

                let value = CommandLine.arguments[valueIndex]

                let result = ValueArgument.validate(value, forType: valueArgument.type)
                if !result.0 {
                    if valueArgument.required {
                        Logger.error("Value passed to argument \(argWithDash) is invalid. \(result.1!)")
                        return false
                    } else {
                        Logger.warning("value passed to argument \(argWithDash) is invalid. \(result.1!). Ignoring argument.")
                        continue
                    }
                }

                valueArgument.value = value
            }
        }

        return true
    }

    var usage: String {
        let usageString = "\nUsage: xchtmlreport" + arguments.map { $0.usageString }.joined()
        let optionsString = "\n\nOptions:\n" + arguments.map { "    -\($0.shortFlag)               \($0.helpMessage)\n"}.joined()
        return usageString + optionsString
    }
}
