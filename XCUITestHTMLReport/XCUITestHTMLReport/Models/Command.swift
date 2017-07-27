//
//  Command.swift
//  XCUITestHTMLReport
//
//  Created by Titouan van Belle on 27.07.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation

struct Command
{
    var arguments: [Argument]

    var isValid: Bool {
        if CommandLine.arguments.index(of: "-h") != nil {
            print(usage)
            exit(EXIT_SUCCESS)
        }

        let flagIndexes = CommandLine.arguments.dropFirst().map { $0.first == "-" ? CommandLine.arguments.index(of: $0) : nil }.flatMap { $0 }

        for index in 0..<arguments.count {
            let argument = arguments[index]
            let argWithDash = "-" + argument.shortFlag

            let argIndex = CommandLine.arguments.index(of: argWithDash)
            if argument.required {
                if argIndex == nil {
                    print("Error: Argument \(argWithDash) is required")
                    return false
                }
            }

            let valueIndex = argIndex! + 1
            if CommandLine.arguments.count == valueIndex || flagIndexes.contains(valueIndex) {
                print("Error: No value was passed for argument \(argWithDash)")
                return false
            }

            let value = CommandLine.arguments[valueIndex]

            if !Argument.validate(value, forType: argument.type) {
                if argument.required {
                    print("Error: value passed to argument \(argWithDash) is invalid. Expected a \(argument.type.rawValue)")
                    return false
                } else {
                    print("Warning")
                }
            }

            argument.value = value
        }

        return true
    }

    var usage: String {
        let usageString = "\nUsage: xchtmlreport" + arguments.map { $0.usageString }.joined()
        let optionsString = "\n\nOptions:\n" + arguments.map { "    -\($0.shortFlag)               \($0.helpMessage)\n"}.joined()
        return usageString + optionsString
    }

    init(arguments args: [Argument]) {
        arguments = args
    }
}
