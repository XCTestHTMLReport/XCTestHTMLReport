//
//  ReportNormalizer.swift
//
//  Report element identifiers are a digest of each element's structural path
//  through the report (see `IdentifierPath`, #411/#430). Two renders on one
//  backend therefore agree byte-for-byte and need no normalization.
//
//  Two *backends* do not: the modern reader's tree omits the "All tests" and
//  "<bundle>.xctest" wrapper levels, so the same test case sits at a different
//  path under each backend and digests differently. The cross-backend
//  differential normalizes those digests away; nothing else does.
//

import Foundation

/// `IdentifierPath.identifier` is the first 128 bits of a SHA-256, lowercase hex.
/// Anchored with word boundaries so it cannot bite into a longer hex run.
private let identifierPattern: NSRegularExpression = {
    guard let pattern = try? NSRegularExpression(pattern: "\\b[0-9a-f]{32}\\b") else {
        preconditionFailure("The identifier pattern is a constant and must compile")
    }
    return pattern
}()

/// Replaces every `IdentifierPath` digest with the literal `ID`.
///
/// Only safe on reports rendered in `.linking` mode. Inline rendering embeds
/// base64 payloads, where a 32-character run drawn from `[0-9a-f]` is possible;
/// the differential renders `.linking` for this reason.
func normalizeIdentifiers(_ html: String) -> String {
    identifierPattern.stringByReplacingMatches(
        in: html,
        range: NSRange(html.startIndex..., in: html),
        withTemplate: "ID"
    )
}
