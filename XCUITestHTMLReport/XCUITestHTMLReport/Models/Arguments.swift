//
//  Arguments.swift
//  XCUITestHTMLReport
//
//  Created by Titouan van Belle on 21.07.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation

struct Arguments
{
    private var arguments = [String: String]()

    var results: String? {
        return arguments["-r"]
    }

    init(arguments: [String])
    {
        for (index, string) in arguments.enumerated() {
            guard index != 0 else {
                continue
            }

            if index % 2 != 0 {
                self.arguments[string] = arguments[index+1]
            }
        }
    }
}
