//
//  IdentifierPath.swift
//  XCTestHTMLReport
//
//  Created for #411: reports must be reproducible.
//

import CryptoKit
import Foundation

/// A location in the report tree, used to mint the element identifiers that
/// end up in HTML `id` attributes and in the JavaScript handles the report
/// navigates itself with (`selectDevice('…')`, `toggle(this, '…')`).
///
/// These identifiers used to be `UUID()`, which made the same bundle render
/// differently on every run. They are now a digest of the path to the element,
/// so the same bundle always renders the same bytes.
///
/// ## Why a digest and not the path itself
///
/// The path is built from bundle content — target names, suite and test
/// identifiers — and those are free-form: Swift test names can contain quotes,
/// angle brackets, spaces and non-ASCII. The templates interpolate identifiers
/// into an unquoted-by-them `id` attribute *and* into a single-quoted
/// JavaScript string, neither of which is escaped, so the raw path cannot be
/// used. A hex digest is safe in both.
///
/// ## Why the identifiers are unique within a report
///
/// Uniqueness comes from the path, not from the digest being collision-free.
/// Each node appends a component that distinguishes it from its siblings:
///
/// - runs: the index of the bundle and of the action within it
/// - devices: one per run, under that run's path
/// - target summaries and suites: their index among their siblings
/// - test cases: their test identifier, which is unique among a suite's cases
///   because `TestGroup` dedupes them into a `Set` keyed on exactly that
/// - iterations: their index within the owning test case, assigned after any
///   merging and sorting has happened
///
/// Distinct sibling components therefore give distinct paths, and no
/// name-based collision is possible — the same test name under two suites,
/// two targets or two devices sits at two different paths. Components are
/// length-prefixed when joined so that a component containing the separator
/// (test identifiers such as `MySuite/testFoo()` do) cannot forge a different
/// node's path.
struct IdentifierPath {
    private let path: String

    static let root = IdentifierPath(path: "")

    func appending(_ component: String) -> IdentifierPath {
        // Length-prefixed, so the mapping from component list to string is
        // injective: "ab" + "c" and "a" + "bc" cannot both become "/ab/c".
        IdentifierPath(path: "\(path)\(component.utf8.count):\(component)/")
    }

    /// The first 128 bits of the path's SHA-256, hex encoded.
    ///
    /// Matches `[0-9a-f]{32}`: no quotes, angle brackets, or anything else that
    /// would need escaping in an HTML attribute or a JavaScript string literal.
    var identifier: String {
        SHA256.hash(data: Data(path.utf8))
            .prefix(16)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
