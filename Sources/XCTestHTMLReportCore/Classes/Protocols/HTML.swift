//
//  HTML.swift
//  XCTestHTMLReport
//
//  Created by Titouan van Belle on 22.07.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation

protocol HTML {
    var htmlTemplate: String { get }
    var htmlPlaceholderValues: [String: String] { get }
}

extension HTML {
    var html: String {
        htmlPlaceholderValues
            .reduce(htmlTemplate) { (accumulator: String, rel: (String, String)) -> String in
                autoreleasepool {
                    accumulator.replacingOccurrences(of: "[[\(rel.0)]]", with: rel.1)
                }
            }
    }
}

extension Sequence where Element: HTML {
    var accumulateHTMLAsString: String {
        reduce("") { (accumulator: String, element: HTML) -> String in
            accumulator + element.html
        }
    }
}

extension Sequence where Element: Test {
    func accumulateHtml() -> String {
        reduce("") { $0 + $1.html }
    }
}
