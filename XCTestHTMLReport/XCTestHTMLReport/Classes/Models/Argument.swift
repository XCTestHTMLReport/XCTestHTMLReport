//
//  Arguments.swift
//  XCTestHTMLReport
//
//  Created by Titouan van Belle on 21.07.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation

class Argument
{
    enum ArgumentType: String {
        case path = "path"
        case bool = "bool"
    }

    let shortFlag: String

    let optionName: String?
    let helpMessage: String
    let type: ArgumentType
    let required: Bool
    let allowsMultiple: Bool

    var usageString: String {
        guard required else {
            return ""
        }

        var string = "-\(shortFlag)"
        if let optionName = optionName {
            string += " <\(optionName)>"
        }

        return " \(string)"
    }

    init(_ type: ArgumentType, _ shortFlag: String, _ optionName: String?, required: Bool, allowsMultiple: Bool, helpMessage: String)
    {
        self.shortFlag = shortFlag
        self.optionName = optionName
        self.helpMessage = helpMessage
        self.type = type
        self.required = required
        self.allowsMultiple = allowsMultiple
    }
}

class ValueArgument: Argument
{
    var values = [String]()

    class func validate(_ value: String, forType type: ArgumentType) -> (Bool, String?)
    {
        switch type {
        case .path:
            return (FileManager.default.fileExists(atPath: value), "Invalid path: \(value)")
        default:
            return (false, "")
        }
    }
}

class BlockArgument: Argument
{
    var block:  () -> ()

    init(_ shortFlag: String, _ optionName: String?, required: Bool, helpMessage: String, block: @escaping () -> ())
    {
        self.block = block
        super.init(.bool, shortFlag, optionName, required: required, allowsMultiple: false, helpMessage: helpMessage)
    }
}
