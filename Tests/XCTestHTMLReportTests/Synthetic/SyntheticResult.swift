//
//  SyntheticResult.swift
//
//  Builds a ParsedResult tree from constants. Task 2 extends this to the full
//  tree; Task 1 needs only enough to construct Activity values.
//

import Foundation
@testable import XCTestHTMLReportCore

enum SyntheticResult {
    static let pngReference = "payload-png"
    static let textReference = "payload-text"

    static var payloads: StubPayloadProvider {
        StubPayloadProvider(exports: [
            pngReference: StubPayloadProvider.onePixelPNG,
            textReference: StubPayloadProvider.plainText,
        ])
    }

    static func pngAttachment(reference: String = pngReference) -> ParsedAttachment {
        ParsedAttachment(
            name: "Screenshot",
            filename: "screenshot.png",
            filenameExtension: "png",
            payloadReference: reference
        )
    }

    static func activity(
        title: String,
        attachments: [ParsedAttachment] = [],
        subActivities: [ParsedActivity] = []
    ) -> ParsedActivity {
        ParsedActivity(
            title: title,
            isFailure: false,
            start: Date(timeIntervalSince1970: 0),
            attachments: attachments,
            subActivities: subActivities
        )
    }

    /// Renders parsed activities into model `Activity` values, which is what
    /// `TestScreenshotFlow` consumes.
    static func activities(_ parsed: [ParsedActivity]) -> [Activity] {
        let provider = payloads
        return parsed.enumerated().map { index, item in
            Activity(
                activity: item,
                identifierPath: IdentifierPath.root.appending("activity-\(index)"),
                file: provider,
                renderingMode: .linking,
                downsizeImagesEnabled: false,
                downsizeScaleFactor: 0.5
            )
        }
    }
}
