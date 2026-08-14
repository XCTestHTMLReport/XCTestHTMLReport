//
//  LegacyRunLogDocument.swift
//  XCTestHTMLReportCore
//
//  Decodes the log document of `xcresulttool get --legacy --format json`.
//  Leaves with the rest of the legacy backend.
//

import Foundation

// MARK: - LegacyRunLogDocument

/// One node of the legacy log document.
///
/// Deliberately not read through XCResultKit, which loses most of the tree in
/// a way callers cannot work around. `XCResultFile.getLogs(id:)` returns an
/// `ActivityLogSection`, and XCResultKit decodes that type's children as
/// `xcArray(element: "subsections", from: json).ofType(ActivityLogSection.self)`
/// — where `ofType` keeps only the elements whose `_type._name` matches
/// *exactly*. The real document is polymorphic: its `ActivityLogUnitTestSection`
/// and `ActivityLogCommandInvocationSection` nodes carry the test targets, the
/// install actions and the launch lines, and every one of them was discarded
/// at decode time, before any code of ours ran (#480).
///
/// So this reads the fields every node shares and ignores `_type` entirely,
/// which is also what makes it indifferent to a node type Apple adds later:
/// an unrecognised subtype keeps its title, its messages and its children
/// rather than vanishing.
struct LegacyRunLogDocument: Decodable {
    let title: String
    let messages: [String]
    let subsections: [LegacyRunLogDocument]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Every key here is absent rather than null when it has nothing in it
        // — an empty `messages` array is simply not written — so all three are
        // optional reads with an empty default.
        title = try container
            .decodeIfPresent(LegacyValue.self, forKey: .title)?.value ?? ""
        messages = try container
            .decodeIfPresent(LegacyValues<LegacyMessage>.self, forKey: .messages)?
            .values.map(\.text) ?? []
        subsections = try container
            .decodeIfPresent(LegacyValues<LegacyRunLogDocument>.self, forKey: .subsections)?
            .values ?? []
    }

    /// The backend-neutral shape the exporter formats.
    var runLogSection: RunLogSection {
        RunLogSection(
            title: title,
            messages: messages,
            subsections: subsections.map(\.runLogSection)
        )
    }

    // MARK: Private

    private enum CodingKeys: String, CodingKey {
        case title
        case messages
        case subsections
    }
}

// MARK: - LegacyValue

/// A legacy scalar, which is always wrapped: `{"_type": …, "_value": "…"}`.
private struct LegacyValue: Decodable {
    let value: String

    private enum CodingKeys: String, CodingKey {
        case value = "_value"
    }
}

// MARK: - LegacyValues

/// A legacy array, which is always wrapped: `{"_type": …, "_values": [ … ]}`.
private struct LegacyValues<Element: Decodable>: Decodable {
    let values: [Element]

    private enum CodingKeys: String, CodingKey {
        case values = "_values"
    }
}

// MARK: - LegacyMessage

/// An `ActivityLogMessage`. `title` is the line Xcode's Log view shows;
/// `shortTitle` is its abbreviation and stands in only when there is no
/// title, which is the same precedence the modern reader applies.
private struct LegacyMessage: Decodable {
    let text: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decodeIfPresent(LegacyValue.self, forKey: .title)?.value
            ?? container.decodeIfPresent(LegacyValue.self, forKey: .shortTitle)?.value
            ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case title
        case shortTitle
    }
}
