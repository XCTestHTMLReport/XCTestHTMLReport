//
//  Arguments.swift
//  XCUITestHTMLReport
//
//  Created by Titouan van Belle on 21.07.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation

class Argument
{
    class func validate(_ value: String, forType type: ArgumentType) -> Bool
    {
        switch type {
        case .path:
            return FileManager.default.fileExists(atPath: value)
        }
    }

    enum ArgumentType: String {
        case path = "path"
    }

    let shortFlag: String

    let optionName: String?
    let helpMessage: String
    let type: ArgumentType
    let required: Bool

    var value: String?

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

    init(_ type: ArgumentType, _ shortFlag: String, _ optionName: String?, required: Bool, helpMessage: String)
    {
        self.shortFlag = shortFlag
        self.optionName = optionName
        self.helpMessage = helpMessage
        self.type = type
        self.required = required
    }
}
