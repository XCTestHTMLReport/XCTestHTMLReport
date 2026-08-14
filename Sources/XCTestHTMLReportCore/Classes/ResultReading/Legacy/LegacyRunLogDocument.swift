//
//  LegacyRunLogDocument.swift
//  XCTestHTMLReportCore
//
//  Decodes the log document of `xcresulttool get --legacy --format json`.
//  Leaves with the rest of the legacy backend.
//

import Foundation

// MARK: - LegacyRunLogDocument

/// What `xcresulttool get --legacy --id … --format json` answers with, once
/// it is established that the answer is a log document at all.
///
/// The node below reads every field permissively, which is what a document
/// this decoder does not fully recognise needs. Applied to the root as well,
/// that tolerance says yes to anything: `{}` decodes, formats to
/// `--------  --------`, and ships as this run's log with nothing to say it
/// went wrong — the #480 failure again, one layer earlier. So the root, and
/// only the root, has to carry `domainType`. It is on every node of a real
/// document (46 of 46 in `TestResults`, where `duration` is on 37), so no
/// document that is one pays for it, and a document that is not one throws
/// into `runLogText`'s `catch`, which records `.logExportFailed`.
struct LegacyRunLogDocument: Decodable {
    let root: LegacyRunLogNode

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Decoded for its presence, not its value: nothing downstream reads
        // the domain, and a document that omits it is not one to read.
        _ = try container.decode(LegacyValue.self, forKey: .domainType)
        root = try LegacyRunLogNode(from: decoder)
    }

    /// The backend-neutral shape the exporter formats.
    var runLogSection: RunLogSection {
        root.runLogSection
    }

    // MARK: Private

    private enum CodingKeys: String, CodingKey {
        case domainType
    }
}

// MARK: - LegacyRunLogNode

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
/// rather than vanishing. Requiring anything here would give that up, which
/// is why the check above stops at the root.
struct LegacyRunLogNode: Decodable {
    let title: String
    let messages: [String]
    let subsections: [LegacyRunLogNode]

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
            .decodeIfPresent(LegacyValues<LegacyRunLogNode>.self, forKey: .subsections)?
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
