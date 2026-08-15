//
//  HTMLEscapingTests.swift
//
//  Every value the `HTML` seam substitutes into a template is written into
//  markup verbatim. Values that are already rendered HTML must stay that
//  way; leaf text must not. These tests pin that split at the two places it
//  can go wrong — a value breaking out of the attribute that holds it, and a
//  value reaching a JavaScript string literal, where XML escaping cannot
//  help because the browser decodes the attribute before compiling the JS.
//

import XCTest
@testable import XCTestHTMLReportCore

final class HTMLEscapingTests: XCTestCase {
    private static let hostileFilename =
        "FileName with DoubleQuote\"SingleQuote'LessThan<GreaterThan>Ampersand&.txt"

    private static let escapedHostileFilename =
        "FileName with DoubleQuote&quot;SingleQuote&apos;LessThan&lt;GreaterThan&gt;Ampersand&amp;.txt"

    private func syntheticHTML() -> String {
        Summary(
            parsedRuns: [SyntheticResult.parsedRun],
            payloads: SyntheticResult.payloads,
            renderingMode: .linking,
            downsizeImagesEnabled: false,
            downsizeScaleFactor: 0.5,
            bundleNames: ["Synthetic"]
        ).generatedHtmlReport()
    }

    /// A run whose *every* leaf string is hostile. `Attachment` is only one
    /// of the types feeding the substitution seam; this covers the titles,
    /// identifiers and destination fields that `Test`, `Iteration`, `Run`
    /// and `RunDestination` contribute.
    private func hostileRunHTML() -> String {
        let hostile = "\"'<>&"
        let group = ParsedGroup(
            name: "Suite\(hostile)",
            identifier: "Suite\(hostile)",
            duration: 1,
            children: [.testCase(SyntheticResult.testCase(
                name: "testHostile\(hostile)()",
                iterations: [SyntheticResult.iteration(
                    number: nil,
                    status: .passed,
                    activities: []
                )]
            ))]
        )
        let run = ParsedRun(
            destination: ParsedDestination(
                displayName: "Device\(hostile)",
                deviceIdentifier: "identifier\(hostile)",
                modelName: "Model\(hostile)",
                operatingSystemVersion: "1.0\(hostile)"
            ),
            logReference: SyntheticResult.logReference,
            testables: [ParsedTestable(targetName: "HostileTests", groups: [group])]
        )
        return Summary(
            parsedRuns: [run],
            payloads: SyntheticResult.payloads,
            renderingMode: .linking,
            downsizeImagesEnabled: false,
            downsizeScaleFactor: 0.5,
            bundleNames: ["Synthetic"]
        ).generatedHtmlReport()
    }

    /// Every `foo="..."` in the rendered document, as raw attribute values.
    private func attributeValues(named name: String, in html: String) throws -> [String] {
        let pattern = "\(name)=\"([^\"]*)\""
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(html.startIndex ..< html.endIndex, in: html)
        return regex.matches(in: html, range: range).compactMap { match in
            Range(match.range(at: 1), in: html).map { String(html[$0]) }
        }
    }

    func testHostileFilenameIsWrittenIntoMarkupEscaped() {
        let html = syntheticHTML()
        XCTAssertTrue(
            html.contains(Self.escapedHostileFilename),
            "the filename must reach the document in its escaped form"
        )
        XCTAssertFalse(
            html.contains(Self.hostileFilename),
            "no raw copy of the filename may survive anywhere in the document"
        )
    }

    /// The bug's visible symptom: the unescaped `<GreaterThan>` was parsed as
    /// a start tag and a spurious element entered the DOM.
    func testHostileFilenameDoesNotIntroduceAnElement() {
        XCTAssertFalse(
            syntheticHTML().contains("LessThan<GreaterThan>"),
            "the filename's angle brackets must not be parsed as an element"
        )
    }

    /// XML escaping alone cannot make a value safe inside a JS string
    /// literal: the browser resolves `&apos;` back to `'` before the
    /// attribute is compiled as JavaScript. The only fix is to stop
    /// interpolating the value into the handler at all, so no `onclick` may
    /// carry attachment-derived text.
    func testNoOnclickHandlerEmbedsAnAttachmentFilename() throws {
        let handlers = try attributeValues(named: "onclick", in: syntheticHTML())
        XCTAssertFalse(handlers.isEmpty, "the report must still wire up click handlers")
        let offenders = handlers.filter { $0.contains("FileName with DoubleQuote") }
        XCTAssertEqual(
            offenders,
            [],
            "a filename inside a JS string literal stays injectable however it is escaped"
        )
    }

    /// `toggle(this, '...')` and `selectDevice('...', this)` interpolate too,
    /// but what they interpolate is an `IdentifierPath.identifier` — the
    /// first 128 bits of a SHA-256, hex encoded. That shape is what makes
    /// them safe, so it is the thing worth pinning: if identifier generation
    /// ever starts passing raw test or device names through, these handlers
    /// become injectable and this test is the tripwire.
    func testEveryIdentifierReachingAScriptHandlerIsAHexDigest() throws {
        let interpolated = try attributeValues(named: "onclick", in: hostileRunHTML())
            .filter { $0.hasPrefix("toggle(") || $0.hasPrefix("selectDevice(") }
            .compactMap { handler -> String? in
                guard let open = handler.firstIndex(of: "'") else {
                    return nil
                }
                let rest = handler[handler.index(after: open)...]
                guard let close = rest.firstIndex(of: "'") else {
                    return nil
                }
                return String(rest[..<close])
            }
        XCTAssertFalse(interpolated.isEmpty, "the tree and device list must still pass ids")

        let digest = try NSRegularExpression(pattern: "^[0-9a-f]{32}$")
        let offenders = interpolated.filter { value in
            digest.firstMatch(in: value, range: NSRange(location: 0, length: value.utf16.count))
                == nil
        }
        XCTAssertEqual(
            offenders,
            [],
            "only opaque digests may be interpolated into a JavaScript string literal"
        )
    }

    func testHostileTestAndDeviceNamesAreEscaped() {
        let html = hostileRunHTML()
        XCTAssertTrue(
            html.contains("testHostile&quot;&apos;&lt;&gt;&amp;()"),
            "a test name must reach the document escaped"
        )
        XCTAssertTrue(
            html.contains("Device&quot;&apos;&lt;&gt;&amp;"),
            "a device name must reach the document escaped"
        )
        XCTAssertFalse(
            html.contains("Model\"'<>&"),
            "no raw copy of a destination field may survive"
        )
    }

    /// The summary header (#439, A1) is a second place every hostile leaf
    /// string reaches markup: the digest carries a test name, a suite name and
    /// an assertion message.
    ///
    /// Scoped to `#run-summary` rather than to the whole document on purpose.
    /// The tree below renders the same strings escaped, so a document-wide
    /// "contains the escaped form" assertion would pass even if the header
    /// emitted a raw copy — the very failure mode #463 fixed elsewhere.
    func testTheSummaryHeaderEscapesEveryHostileValue() throws {
        let hostile = "\"'<>&"
        let escaped = "&quot;&apos;&lt;&gt;&amp;"
        let header = try element("section", id: "run-summary", in: hostileFailingRunHTML())

        XCTAssertFalse(
            header.contains(hostile),
            "a raw hostile string reached the summary header"
        )
        for value in ["testHostile\(escaped)()", "Suite\(escaped)",
                      "assertion\(escaped) failed"]
        {
            XCTAssertTrue(
                header.contains(value),
                "the header must render '\(value)' — escaped, but present"
            )
        }
    }

    /// The device picker (#439, A3a) is the third, and the destination fields
    /// moved into it wholesale: A1's device rows lived in `#run-summary` and
    /// carried the name and the OS version, and the sidebar carried the model.
    /// The picker carries all three, so the scoped assertion follows them
    /// rather than staying pointed at a region they left.
    ///
    /// Scoped for the same reason the header's is: every one of these strings
    /// is rendered escaped somewhere else on the page too, so a document-wide
    /// check would pass on a picker that emitted a raw copy.
    func testTheDevicePickerEscapesEveryHostileValue() throws {
        let hostile = "\"'<>&"
        let escaped = "&quot;&apos;&lt;&gt;&amp;"
        let picker = try element("details", id: "device-picker", in: hostileFailingRunHTML())

        XCTAssertFalse(
            picker.contains(hostile),
            "a raw hostile string reached the device picker"
        )
        for value in ["Device\(escaped)", "1.0\(escaped)", "Model\(escaped)"] {
            XCTAssertTrue(
                picker.contains(value),
                "the picker must render '\(value)' — escaped, but present"
            )
        }
    }

    /// The digest hands the page an element id through `data-target` rather
    /// than through an interpolated `onclick`, so it is not covered by
    /// `testEveryIdentifierReachingAScriptHandlerIsAHexDigest`. What makes it
    /// safe is the same property, and it is worth the same tripwire: the
    /// script looks the value up with `getElementById`, so a name reaching it
    /// would be a selector built from test-author-controlled text.
    func testEveryDigestJumpTargetIsAHexDigest() throws {
        let targets = try attributeValues(named: "data-target", in: hostileFailingRunHTML())
        XCTAssertFalse(targets.isEmpty, "the fixture must render a failure digest")

        let digest = try NSRegularExpression(pattern: "^[0-9a-f]{32}$")
        let offenders = targets.filter { value in
            digest.firstMatch(in: value, range: NSRange(location: 0, length: value.utf16.count))
                == nil
        }
        XCTAssertEqual(offenders, [], "only opaque digests may address a row from the digest")
    }

    /// One element's source, by tag and id. Both regions this is used on hold
    /// no nested element of their own tag, so the first matching close tag
    /// after the open is that element's own.
    private func element(_ tag: String, id: String, in html: String) throws -> String {
        let open = try XCTUnwrap(
            html.range(of: "<\(tag) id=\"\(id)\""),
            "the report must render <\(tag) id=\"\(id)\">"
        )
        let close = try XCTUnwrap(
            html.range(of: "</\(tag)>", range: open.upperBound ..< html.endIndex)
        )
        return String(html[open.lowerBound ..< close.upperBound])
    }

    /// `hostileRunHTML`'s test passes, so it renders no digest. This is the
    /// same run with the test failed and its assertion message hostile too.
    private func hostileFailingRunHTML() -> String {
        let hostile = "\"'<>&"
        let failure = ParsedActivity(
            title: "assertion\(hostile) failed",
            isFailure: true,
            start: Date(timeIntervalSince1970: 0),
            attachments: [],
            subActivities: []
        )
        let group = ParsedGroup(
            name: "Suite\(hostile)",
            identifier: "Suite\(hostile)",
            duration: 1,
            children: [.testCase(ParsedTestCase(
                name: "testHostile\(hostile)()",
                identifier: "Suite\(hostile)/testHostile\(hostile)()",
                arguments: [],
                iterations: [SyntheticResult.iteration(
                    number: nil,
                    status: .failed,
                    activities: [failure]
                )]
            ))]
        )
        let run = ParsedRun(
            destination: ParsedDestination(
                displayName: "Device\(hostile)",
                deviceIdentifier: "identifier\(hostile)",
                modelName: "Model\(hostile)",
                operatingSystemVersion: "1.0\(hostile)"
            ),
            logReference: SyntheticResult.logReference,
            testables: [ParsedTestable(targetName: "HostileTests", groups: [group])]
        )
        return Summary(
            parsedRuns: [run],
            payloads: SyntheticResult.payloads,
            renderingMode: .linking,
            downsizeImagesEnabled: false,
            downsizeScaleFactor: 0.5,
            bundleNames: ["Synthetic"]
        ).generatedHtmlReport()
    }

    /// The guard against over-correcting: values that are already rendered
    /// HTML must pass through the seam untouched, or the whole report
    /// collapses into escaped source text.
    func testNestedMarkupIsNotEscaped() {
        let html = syntheticHTML()
        XCTAssertTrue(
            html.contains("<span class=\"icon"),
            "nested markup must remain markup, not become escaped text"
        )
        XCTAssertFalse(
            html.contains("&lt;span"),
            "a rendered child must never be escaped as if it were leaf text"
        )
    }
}
