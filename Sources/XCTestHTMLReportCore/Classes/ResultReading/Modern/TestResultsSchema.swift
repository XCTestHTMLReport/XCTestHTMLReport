//
//  TestResultsSchema.swift
//  XCTestHTMLReportCore
//
//  Codable mirrors of `xcresulttool get test-results ...` and
//  `xcresulttool export attachments`. Field names match the JSON exactly, so
//  no CodingKeys are needed.
//
//  Almost everything is optional: xcresulttool omits empty collections and
//  inapplicable fields rather than emitting nulls, and a missing key must
//  degrade rather than fail the whole read.
//

import Foundation

// MARK: - TestResultsDevice

struct TestResultsDevice: Decodable {
    let deviceId: String?
    let deviceName: String?
    let modelName: String?
    let osVersion: String?
    let platform: String?
}

// MARK: - TestResultsSummary

struct TestResultsSummary: Decodable {
    struct DeviceAndConfiguration: Decodable {
        let device: TestResultsDevice?
    }

    let title: String?
    let environmentDescription: String?
    let totalTestCount: Int?
    let devicesAndConfigurations: [DeviceAndConfiguration]?
}

// MARK: - TestResultsTests

struct TestResultsTests: Decodable {
    let devices: [TestResultsDevice]?
    /// Optional with an empty default: xcresulttool omits collection keys
    /// rather than emitting empty arrays, and a bundle with no tests must
    /// decode to an empty result rather than throwing keyNotFound.
    let testNodes: [TestNode]?
}

// MARK: - TestNode

/// One node of the test tree. `nodeType` is the discriminator; the published
/// `TestNodeType` enum (`xcresulttool get test-results tests --schema`,
/// schema 0.1.0) lists `Test Plan`, `Unit test bundle`, `UI test bundle`,
/// `Test Suite`, `Test Case`, `Device`, `Test Plan Configuration`,
/// `Arguments`, `Repetition`, `Test Case Run`, `Failure Message`,
/// `Source Code Reference`, `Attachment`, `Expression`, `Test Value`, and
/// `Runtime Warning`. `Arguments`, `Expression` and `Test Value` come from
/// the schema alone — no fixture produces them yet — so nothing here may
/// require their presence.
struct TestNode: Decodable {
    let name: String?
    let nodeType: String?
    let nodeIdentifier: String?
    let nodeIdentifierURL: String?
    let result: String?
    let durationInSeconds: Double?
    let details: String?
    let children: [TestNode]?
}

// MARK: - TestActivities

struct TestActivities: Decodable {
    struct TestRun: Decodable {
        let device: TestResultsDevice?
        let activities: [ActivityNode]?
    }

    let testIdentifier: String?
    let testName: String?
    /// Optional for the same reason as `TestResultsTests.testNodes`: an
    /// omitted key must decode, not throw.
    let testRuns: [TestRun]?
}

// MARK: - ActivityNode

struct ActivityNode: Decodable {
    let title: String?
    let startTime: Double?
    let isAssociatedWithFailure: Bool?
    let attachments: [ActivityAttachment]?
    let childActivities: [ActivityNode]?
}

// MARK: - ActivityAttachment

struct ActivityAttachment: Decodable {
    let name: String?
    let payloadId: String?
    let uuid: String?
    let timestamp: Double?
    let lifetime: String?
}

// MARK: - AttachmentManifestEntry

/// `manifest.json` written by `xcresulttool export attachments`.
struct AttachmentManifestEntry: Decodable {
    struct ManifestAttachment: Decodable {
        let exportedFileName: String?
        let suggestedHumanReadableName: String?
        let isAssociatedWithFailure: Bool?
        let timestamp: Double?
    }

    let testIdentifier: String?
    let testIdentifierURL: String?
    let attachments: [ManifestAttachment]?
}

// MARK: - LogSection

/// Section of `xcresulttool get log`. Note there is no `emittedOutput`; the
/// new format carries structured `messages` instead.
struct LogSection: Decodable {
    struct LogMessage: Decodable {
        let title: String?
        let shortTitle: String?
        let type: String?
    }

    let title: String?
    let domainType: String?
    let duration: Double?
    let result: String?
    let messages: [LogMessage]?
    let subsections: [LogSection]?

    /// The backend-neutral shape the exporter formats. `messages` is the log
    /// on this side of the format boundary, and — since the legacy document
    /// describes the same tree with the same messages — on the other side
    /// too, which is what lets the two exports be byte-identical (#480).
    var runLogSection: RunLogSection {
        RunLogSection(
            title: title ?? "",
            messages: (messages ?? []).map { $0.title ?? $0.shortTitle ?? "" },
            subsections: (subsections ?? []).map(\.runLogSection)
        )
    }
}
