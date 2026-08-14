//
//  SampleAppUnitTests.swift
//  SampleAppUnitTests
//
//  Created by Titouan van Belle on 22.12.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import UIKit
import XCTest

class SampleAppUnitTests: XCTestCase {
    func testFailure() {
        XCTAssert(false, "Test failed")
    }

    /// Records with result `Expected Failure` in the xcresult — one of exactly
    /// two such rows in `TestResults.xcresult`. `SwiftTestingSuite.knownIssue`
    /// records the other from this same target, so the status has coverage from
    /// both test frameworks; `RetryTests` records one too, but it is skipped
    /// from this bundle and lands in `RetryResults.xcresult`. #439 has since
    /// given the status its own `Status.expectedFailure` and glyph, and
    /// `CoreTests`' bucket arithmetic subtracts exactly these two.
    func testExpectedFailure() {
        XCTExpectFailure("Intentional expected failure for fixture coverage") {
            XCTAssert(false, "This assertion fails inside XCTExpectFailure")
        }
    }

    /// Attaches a genuine PNG. Every other data attachment in the fixtures is
    /// txt, log, html, or mp4 — `testAttachScreenshot` goes through the
    /// screenshot machinery, not the plain-attachment path — so the
    /// extension-derived `.png` attachment type had no fixture exercising it.
    /// The image is generated in code to keep binaries out of the repo; an
    /// 8×8 solid fill is ~100 bytes of PNG. See #439.
    func testWithPngAttachment() throws {
        let size = CGSize(width: 8, height: 8)
        // `UIGraphicsImageRenderer` takes points and defaults to the screen's
        // scale, so on a Retina simulator the plain `init(size:)` would emit a
        // 16×16 or 24×24 PNG. Pin scale 1 so the fixture is the 8×8 it claims.
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.systemRed.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        let attachment = try XCTAttachment(
            data: XCTUnwrap(image.pngData()),
            uniformTypeIdentifier: "public.png"
        )
        attachment.name = "TinyRedSquare"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testSuccess() {
        XCTAssert(true, "Test succeeded")
    }

    func testSkipped() throws {
        // This requires Xcode 11.4 and later
        let letsSkipThis = true
        try XCTSkipIf(letsSkipThis, "Test skipped")
    }

    func testWithLogAttachment() {
        let logData = "log1\nlog2\nlog3".data(using: .utf8)!
        let attachment = XCTAttachment(data: logData, uniformTypeIdentifier: "com.apple.log")
        attachment.name = "myLogFile"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testWithLogAttachmentWithoutName() {
        let logData = "log4\nlog5\nlog6".data(using: .utf8)!
        let attachment = XCTAttachment(data: logData, uniformTypeIdentifier: "com.apple.log")
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
