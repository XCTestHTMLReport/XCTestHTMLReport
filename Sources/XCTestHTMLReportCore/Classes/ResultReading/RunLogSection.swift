//
//  RunLogSection.swift
//  XCTestHTMLReportCore
//
//  The run log, in the one shape both backends reduce their document to.
//

import Foundation

/// One node of a run log: a titled section, the messages it emitted, and its
/// children.
///
/// Both backends read the same tree out of the same bundle — node for node,
/// message for message — so the exported log is the same text on either
/// reader. Keeping the shape and the formatter in one place is what makes
/// that true by construction instead of by coincidence: the legacy path used
/// to format its own way and exported four section titles and nothing else
/// (#480).
///
/// `messages` is the log. The legacy document additionally populates
/// `emittedOutput` on its unit-test nodes, and that is deliberately not part
/// of this shape: it is the per-row console popover in Xcode rather than
/// anything its Log view shows, it nests cumulatively so a parent repeats
/// every descendant's text, and the modern format has no counterpart to it at
/// all. Exporting it would make the two backends permanently unequal in
/// return for content Xcode itself does not put in this view.
struct RunLogSection {
    let title: String
    let messages: [String]
    let subsections: [RunLogSection]

    /// The exported log text, in the layout Xcode's own Log view uses under
    /// `All Messages`: a section header, the messages it emitted, then each
    /// child one tab deeper.
    func formatted(depth: Int = 0) -> String {
        let indent = String(repeating: "\t", count: depth)
        var lines = ["\(indent)-------- \(title) --------"]
        for message in messages {
            lines.append("\(indent)\(message)")
        }
        for subsection in subsections {
            lines.append(subsection.formatted(depth: depth + 1))
        }
        return lines.joined(separator: "\n")
    }
}
