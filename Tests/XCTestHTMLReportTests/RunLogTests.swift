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
    ///
    /// Only the root carries `domainType`, the one key the decoder requires.
    /// A real document has it on every node, but leaving it off the children
    /// here pins the asymmetry: the nodes stay permissive so an unfamiliar
    /// subtype keeps its content, and it is the root alone that has to prove
    /// this is a log document at all.
    private let legacyDocument = Data("""
    {
      "_type": { "_name": "ActivityLogSection" },
      "domainType": {
        "_type": { "_name": "String" },
        "_value": "com.apple.dt.unit.cocoaUnitTest"
      },
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
            document.root.subsections.map(\.title),
            ["Launch actions", "Test target SampleAppUnitTests"],
            "An ActivityLogUnitTestSection child must survive decoding"
        )
        XCTAssertEqual(
            document.root.subsections.first?.subsections.map(\.title),
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
            document.root.subsections.first?.messages,
            ["Platform: iOS Simulator", "Target Architecture: arm64"]
        )
        XCTAssertEqual(
            document.root.title, "Test MainScheme",
            "The root carries no messages of its own; its title is still the header"
        )
        XCTAssertEqual(document.root.messages, [], "An absent `messages` key is no messages")
    }

    /// The root is the one node that has to prove the document is a log
    /// document.
    ///
    /// Reading every field permissively is what keeps an unfamiliar node type
    /// intact, but applied to the root it also accepts `{}`, which formats to
    /// `--------  --------` — 18 bytes of nothing, exported with no fault.
    /// That is the #480 signature again, moved one layer earlier. `domainType`
    /// is on 46 of the real `TestResults` document's 46 nodes (`duration` is
    /// on 37, so not that one), so requiring it costs no real document
    /// anything.
    func testLegacyDecoderRejectsARootThatIsNotALogDocument() {
        XCTAssertThrowsError(
            try JSONDecoder().decode(LegacyRunLogDocument.self, from: Data("{}".utf8)),
            "Well-formed JSON of the wrong shape is not an empty log, it is a fault"
        )
    }

    /// …and the requirement stops there. A node Apple ships without the keys
    /// this decoder happens to know is exactly the case the hand-written
    /// decoder exists to survive, so strictness that recursed would trade the
    /// #480 husk for a #480 fault on a log that is perfectly readable.
    func testLegacyDecoderKeepsChildrenThatDeclareNoDomainType() throws {
        let document = try JSONDecoder().decode(
            LegacyRunLogDocument.self,
            from: Data("""
            {
              "domainType": { "_type": { "_name": "String" }, "_value": "com.apple.dt.unit.cocoaUnitTest" },
              "title": { "_type": { "_name": "String" }, "_value": "Test MainScheme" },
              "subsections": {
                "_type": { "_name": "Array" },
                "_values": [
                  {
                    "_type": { "_name": "ActivityLogSectionAppleShipsNextYear" },
                    "title": { "_type": { "_name": "String" }, "_value": "Something new" },
                    "messages": {
                      "_type": { "_name": "Array" },
                      "_values": [
                        {
                          "_type": { "_name": "ActivityLogMessage" },
                          "title": { "_type": { "_name": "String" }, "_value": "Kept anyway" }
                        }
                      ]
                    }
                  }
                ]
              }
            }
            """.utf8)
        )

        XCTAssertEqual(
            document.root.subsections.map(\.title), ["Something new"],
            "A child that carries no `domainType` is still part of the log"
        )
        XCTAssertEqual(
            document.root.subsections.first?.messages, ["Kept anyway"],
            "…and it keeps its content, which is the whole reason for this decoder"
        )
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
    /// while carrying no counterpart at all to the legacy `emittedOutput`
    /// above, which is why neither shape has one.
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
            { "title": "Test target SampleAppUnitTests" }
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
