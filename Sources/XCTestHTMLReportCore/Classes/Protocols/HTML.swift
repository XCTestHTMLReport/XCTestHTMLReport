//
//  HTML.swift
//  XCTestHTMLReport
//
//  Created by Titouan van Belle on 22.07.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation

/// Values are substituted into the template verbatim, so escaping is the
/// conformer's job and every placeholder falls into exactly one of three
/// cases:
///
/// - **Leaf text** — a title, a file name, a device name, a source path.
///   Escape it with `stringByEscapingXMLChars`. It is written straight into
///   an attribute or a text node, and anything from an `.xcresult` is
///   ultimately test-author controlled.
/// - **Rendered markup** — a child's `html`, an icon's `iconHTML`. Escaping
///   it would turn the report into a page of its own source. Pass it through.
/// - **Opaque, by construction** — an `IdentifierPath.identifier` (a hex
///   digest), a count, a CSS class from an enum. Escaping is a no-op.
///
/// Nothing here can enforce that split, so a new placeholder needs the
/// author to say which case it is. `HTMLEscapingTests` pins the first and
/// second; the third is pinned at `IdentifierPath.identifier`.
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
