//
//  String+Path.swift
//  XCTestHTMLReport
//
//  Created by Titouan Van Belle on 26.11.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation

extension String
{
    func dropLastPathComponent() -> String
    {
        return components(separatedBy: "/").dropLast().joined(separator: "/")
    }
}
