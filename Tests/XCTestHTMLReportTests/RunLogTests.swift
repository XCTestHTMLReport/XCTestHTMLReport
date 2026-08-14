//
//  RunLogTests.swift
//
//  The run log's shape, its two decoders and its one formatter (#480). The
//  differential proves the two backends agree on a real bundle; these pin the
//  specific losses that made them disagree, on documents small enough to read.
//

import XCTest
@testable import XCTestHTMLReportCore

final class RunLogTests: XCTestCase {
    /// A legacy log document in miniature, faithful to the real one: every
    /// scalar wrapped in a `_value` envelope, every array in `_values`, and a
    /// polymorphic tree — a plain `ActivityLogSection` root over an
    /// `ActivityLogUnitTestSection` and an `ActivityLogCommandInvocationSection`.
    private let legacyDocument = Data("""
    {
      "_type": { "_name": "ActivityLogSection" },
      "title": { "_type": { "_name": "String" }, "_value": "Test MainScheme" },
      "subsections": {
        "_type": { "_name": "Array" },
        "_values": [
          {
            "_type": { "_name": "ActivityLogSection" },
            "title": { "_type": { "_name": "String" }, "_value": "Launch actions" },
            "messages": {
              "_type": { "_name": "Array" },
              "_values": [
                {
                  "_type": { "_name": "ActivityLogMessage" },
                  "title": { "_type": { "_name": "String" }, "_value": "Platform: iOS Simulator" },
                  "shortTitle": { "_type": { "_name": "String" }, "_value": "Platform" }
                },
                {
                  "_type": { "_name": "ActivityLogMessage" },
                  "shortTitle": { "_type": { "_name": "String" }, "_value": "Target Architecture: arm64" }
                }
              ]
            },
            "subsections": {
              "_type": { "_name": "Array" },
              "_values": [
                {
                  "_type": {
                    "_name": "ActivityLogCommandInvocationSection",
                    "_supertype": { "_name": "ActivityLogSection" }
                  },
                  "title": { "_type": { "_name": "String" }, "_value": "Install Actions" },
                  "messages": {
                    "_type": { "_name": "Array" },
                    "_values": [
                      {
                        "_type": { "_name": "ActivityLogMessage" },
                        "title": { "_type": { "_name": "String" }, "_value": "Successfully installed" }
                      }
                    ]
                  }
                }
              ]
            }
          },
          {
            "_type": {
              "_name": "ActivityLogUnitTestSection",
              "_supertype": { "_name": "ActivityLogSection" }
            },
            "title": { "_type": { "_name": "String" }, "_value": "Test target SampleAppUnitTests" },
            "emittedOutput": {
              "_type": { "_name": "String" },
              "_value": "Test Case '-[SampleAppUnitTests testSuccess]' passed."
            }
          }
        ]
      }
    }
    """.utf8)

    /// The primary loss. XCResultKit decodes `subsections` as
    /// `ofType(ActivityLogSection.self)`, which keeps only children whose
    /// `_type._name` matches exactly — so both subtyped nodes below, and
    /// everything under them, disappeared before the formatter ran.
    func testLegacyDecoderKeepsSubtypedSubsections() throws {
        let document = try JSONDecoder().decode(
            LegacyRunLogDocument.self, from: legacyDocument
        )

        XCTAssertEqual(
            document.subsections.map(\.title),
            ["Launch actions", "Test target SampleAppUnitTests"],
            "An ActivityLogUnitTestSection child must survive decoding"
        )
        XCTAssertEqual(
            document.subsections.first?.subsections.map(\.title),
            ["Install Actions"],
            "An ActivityLogCommandInvocationSection child must survive decoding"
        )
    }

    /// The secondary loss. `ActivityLogSection` has no `emittedOutput` at all
    /// — the property is declared on the subtype — so the formatter written
    /// against it read nothing from the nodes it did keep. `messages` is where
    /// their content is, and `shortTitle` stands in when a message has no
    /// title, exactly as on the modern side.
    func testLegacyDecoderReadsMessagesAndFallsBackToShortTitle() throws {
        let document = try JSONDecoder().decode(
            LegacyRunLogDocument.self, from: legacyDocument
        )

        XCTAssertEqual(
            document.subsections.first?.messages,
            ["Platform: iOS Simulator", "Target Architecture: arm64"]
        )
        XCTAssertEqual(
            document.title, "Test MainScheme",
            "The root carries no messages of its own; its title is still the header"
        )
        XCTAssertEqual(document.messages, [], "An absent `messages` key is no messages")
    }

    func testFormattedLaysOutHeadersMessagesThenChildren() throws {
        let document = try JSONDecoder().decode(
            LegacyRunLogDocument.self, from: legacyDocument
        )

        XCTAssertEqual(
            document.runLogSection.formatted(),
            """
            -------- Test MainScheme --------
            \t-------- Launch actions --------
            \tPlatform: iOS Simulator
            \tTarget Architecture: arm64
            \t\t-------- Install Actions --------
            \t\tSuccessfully installed
            \t-------- Test target SampleAppUnitTests --------
            """
        )
    }

    /// The two decoders must reduce the same tree to the same shape, or the
    /// shared formatter is shared in name only. The modern document describes
    /// this bundle's log identically — node for node, message for message —
    /// and leaves `emittedOutput` null throughout.
    func testModernDocumentReducesToTheSameShape() throws {
        let modernDocument = Data("""
        {
          "title": "Test MainScheme",
          "subsections": [
            {
              "title": "Launch actions",
              "messages": [
                { "title": "Platform: iOS Simulator", "shortTitle": "Platform" },
                { "shortTitle": "Target Architecture: arm64" }
              ],
              "subsections": [
                {
                  "title": "Install Actions",
                  "messages": [{ "title": "Successfully installed" }]
                }
              ]
            },
            { "title": "Test target SampleAppUnitTests", "emittedOutput": null }
          ]
        }
        """.utf8)

        let modern = try JSONDecoder().decode(LogSection.self, from: modernDocument)
        let legacy = try JSONDecoder().decode(
            LegacyRunLogDocument.self, from: legacyDocument
        )

        XCTAssertEqual(
            modern.runLogSection.formatted(),
            legacy.runLogSection.formatted(),
            "Both backends describe this log the same way; the exports must match"
        )
    }
}
