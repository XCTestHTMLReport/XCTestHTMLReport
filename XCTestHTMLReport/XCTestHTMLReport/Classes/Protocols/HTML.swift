//
//  HTML.swift
//  XCTestHTMLReport
//
//  Created by Titouan van Belle on 22.07.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation

protocol HTML
{
    var htmlTemplate: String { get }
    var htmlPlaceholderValues: [String: String] { get }
}

extension HTML
{
    var html: String {
        return htmlPlaceholderValues.reduce(htmlTemplate, { (accumulator: String, rel: (String, String)) -> String in
            return accumulator.replacingOccurrences(of: "[[\(rel.0)]]", with: rel.1)
        })
    }
}
