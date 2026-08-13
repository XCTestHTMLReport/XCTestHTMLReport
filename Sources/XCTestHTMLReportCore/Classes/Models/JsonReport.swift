//
//  JsonReport.swift
//  XCTestHTMLReportCore
//
//  The `--json` wire contract, implemented. docs/json-schema.md is the
//  contract document; this file makes the output match it.
//
//  This is a deliberate encoding layer, not a synthesized `Encodable` on the
//  `Parsed*` model: every key on the wire is an explicit string below, so
//  renaming a model property breaks this file's compilation instead of
//  silently renaming a public output key. The model is internal and free to
//  change; this file is the contract and changes only with a `schemaVersion`
//  bump per the documented policy.
//
//  Two model fields are deliberately not on the wire: `ParsedRun
//  .logReference` and `ParsedAttachment.payloadReference` are opaque
//  backend-internal handles (a legacy CAS id, a modern attachment uuid) that
//  are meaningless outside this process and could never agree across
//  backends.
//

import Foundation

// MARK: - JsonReport

/// Encodes parsed runs as the documented `--json` schema.
struct JsonReport {
    /// The wire contract's version. Bumped by the policy in
    /// docs/json-schema.md — never as a side effect of a model change.
    static let schemaVersion = "1.0.0"

    let runs: [ParsedRun]

    func encoded() -> String {
        let encoder = JSONEncoder()
        // Sorted keys make two reports over the same bundle byte-comparable,
        // which the contract's ordering guarantees promise. Slashes stay
        // unescaped so test identifiers read as written
        // ("FirstSuite/testOne()", not "FirstSuite\/testOne()").
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard
            let data = try? encoder.encode(JsonDocument(runs: runs)),
            let text = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return text
    }

    /// The five documented status strings. A switch rather than a raw value
    /// so that renaming a `ParsedStatus` case cannot silently rename a wire
    /// value — the compiler forces this list back into review instead.
    fileprivate static func status(_ status: ParsedStatus) -> String {
        switch status {
        case .passed: return "passed"
        case .failed: return "failed"
        case .skipped: return "skipped"
        case .expectedFailure: return "expectedFailure"
        case .unknown: return "unknown"
        }
    }

    /// ISO-8601 UTC with exactly millisecond precision, e.g.
    /// `2026-08-12T21:22:33.123Z`.
    ///
    /// The milliseconds are computed as an integer and appended by hand
    /// rather than via `.withFractionalSeconds`: both backends store the
    /// instant as a `Double`, and a value like 0.123 sits just below its
    /// decimal spelling in binary, so a formatter that truncates can print
    /// `.122` from one backend's double and `.123` from the other's.
    /// Rounding to an integer first makes the two spellings agree whenever
    /// the instants do.
    fileprivate static func timestamp(_ date: Date) -> String {
        let totalMilliseconds = Int((date.timeIntervalSince1970 * 1000).rounded())
        let seconds = totalMilliseconds.quotientAndRemainder(dividingBy: 1000)
        let base = secondsFormatter.string(
            from: Date(timeIntervalSince1970: TimeInterval(seconds.quotient))
        )
        // "…33Z" → "…33.123Z"
        return base.dropLast() + String(format: ".%03dZ", seconds.remainder)
    }

    private static let secondsFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()
}

// MARK: - Wire structures

//
// Each type below hand-writes `encode(to:)` so that the contract's null rule
// holds mechanically: every documented key is written on every emission, and
// an absent value is an explicit `null` — `encode` on an `Optional` writes
// null where the synthesized conformance's `encodeIfPresent` would drop the
// key entirely.
//

private struct JsonDocument: Encodable {
    let runs: [ParsedRun]

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case runs
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(JsonReport.schemaVersion, forKey: .schemaVersion)
        try container.encode(runs.map(JsonRun.init), forKey: .runs)
    }
}

private struct JsonRun: Encodable {
    let run: ParsedRun

    enum CodingKeys: String, CodingKey {
        case destination
        case testables
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(
            JsonDestination(destination: run.destination), forKey: .destination
        )
        try container.encode(run.testables.map(JsonTestable.init), forKey: .testables)
    }
}

private struct JsonDestination: Encodable {
    let destination: ParsedDestination

    enum CodingKeys: String, CodingKey {
        case displayName
        case deviceIdentifier
        case modelName
        case operatingSystemVersion
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(destination.displayName, forKey: .displayName)
        try container.encode(destination.deviceIdentifier, forKey: .deviceIdentifier)
        try container.encode(destination.modelName, forKey: .modelName)
        try container.encode(
            destination.operatingSystemVersion, forKey: .operatingSystemVersion
        )
    }
}

private struct JsonTestable: Encodable {
    let testable: ParsedTestable

    enum CodingKeys: String, CodingKey {
        case targetName
        case groups
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(testable.targetName, forKey: .targetName)
        try container.encode(
            testable.groups.map { JsonNode.group($0) }, forKey: .groups
        )
    }
}

/// The recursive tree node, discriminated by `kind` — consumers switch on
/// it rather than sniffing for keys.
private enum JsonNode: Encodable {
    case group(ParsedGroup)
    case testCase(ParsedTestCase)

    enum CodingKeys: String, CodingKey {
        case kind
        case name
        case identifier
        case duration
        case children
        case arguments
        case iterations
    }

    init(node: ParsedNode) {
        switch node {
        case let .group(group):
            self = .group(group)
        case let .testCase(testCase):
            self = .testCase(testCase)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .group(group):
            try container.encode("group", forKey: .kind)
            try container.encode(group.name, forKey: .name)
            try container.encode(group.identifier, forKey: .identifier)
            try container.encode(group.duration, forKey: .duration)
            try container.encode(group.children.map(JsonNode.init), forKey: .children)
        case let .testCase(testCase):
            try container.encode("testCase", forKey: .kind)
            try container.encode(testCase.name, forKey: .name)
            try container.encode(testCase.identifier, forKey: .identifier)
            try container.encode(testCase.arguments, forKey: .arguments)
            try container.encode(
                testCase.iterations.map(JsonIteration.init), forKey: .iterations
            )
        }
    }
}

private struct JsonIteration: Encodable {
    let iteration: ParsedIteration

    enum CodingKeys: String, CodingKey {
        case iterationNumber
        case status
        case duration
        case activities
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(iteration.iterationNumber, forKey: .iterationNumber)
        try container.encode(JsonReport.status(iteration.status), forKey: .status)
        try container.encode(iteration.duration, forKey: .duration)
        try container.encode(
            iteration.activities.map(JsonActivity.init), forKey: .activities
        )
    }
}

private struct JsonActivity: Encodable {
    let activity: ParsedActivity

    enum CodingKeys: String, CodingKey {
        case title
        case isFailure
        case start
        case attachments
        case subActivities
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(activity.title, forKey: .title)
        try container.encode(activity.isFailure, forKey: .isFailure)
        try container.encode(activity.start.map(JsonReport.timestamp), forKey: .start)
        try container.encode(
            activity.attachments.map(JsonAttachment.init), forKey: .attachments
        )
        try container.encode(
            activity.subActivities.map(JsonActivity.init), forKey: .subActivities
        )
    }
}

private struct JsonAttachment: Encodable {
    let attachment: ParsedAttachment

    enum CodingKeys: String, CodingKey {
        case name
        case filename
        case filenameExtension
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(attachment.name, forKey: .name)
        try container.encode(attachment.filename, forKey: .filename)
        try container.encode(attachment.filenameExtension, forKey: .filenameExtension)
    }
}
