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
        let flagIndexes = CommandLine.arguments.enumerated().map { $0.element.first == "-" ? $0.offset : nil }.compactMap { $0 }

        for index in 0..<arguments.count {
            let argument = arguments[index]
            let argWithDash = "-" + argument.shortFlag

            var argIndexes = CommandLine.arguments.enumerated().filter { $0.element == argWithDash }.map { $0.offset }

            guard argIndexes.count > 0 else {
                if argument.required {
                    Logger.error("Argument \(argWithDash) is required")
                    return false
                }

                continue;
            }

            if !argument.allowsMultiple && argIndexes.count > 1 {
                argIndexes = [argIndexes.first!]
                Logger.error("Found multiple occurences of \(argWithDash). Will only take the first in consideration")
            }

            for argIndex in argIndexes {
                if let blockArgument = argument as? BlockArgument {
                    blockArgument.block()
                } else if let valueArgument = argument as? ValueArgument {
                    let valueIndex = argIndex + 1
                    guard CommandLine.arguments.count != valueIndex && !flagIndexes.contains(valueIndex) else {
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

                    valueArgument.values.append(value)
                }
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
