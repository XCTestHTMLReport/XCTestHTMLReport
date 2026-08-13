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
    static let logReference = "payload-log"

    static var payloads: StubPayloadProvider {
        StubPayloadProvider(exports: [
            pngReference: StubPayloadProvider.onePixelPNG,
            textReference: StubPayloadProvider.plainText,
            logReference: StubPayloadProvider.logText,
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

    static func textAttachment() -> ParsedAttachment {
        ParsedAttachment(
            name: "Log",
            filename: "FileName with DoubleQuote\"SingleQuote'LessThan<GreaterThan>Ampersand&.txt",
            filenameExtension: "txt",
            payloadReference: textReference
        )
    }

    static func iteration(
        number: Int?,
        status: ParsedStatus,
        activities: [ParsedActivity]
    ) -> ParsedIteration {
        ParsedIteration(
            iterationNumber: number,
            status: status,
            duration: 1.5,
            activities: activities
        )
    }

    static func testCase(
        name: String,
        iterations: [ParsedIteration]
    ) -> ParsedTestCase {
        ParsedTestCase(
            name: name,
            identifier: "Synthetic/\(name)",
            arguments: [],
            iterations: iterations
        )
    }

    static var parsedRun: ParsedRun {
        let standardActivities = [
            activity(title: "Start Test", attachments: []),
            activity(
                title: "Attachments",
                attachments: [pngAttachment(), textAttachment()]
            ),
            activity(
                title: "Nested",
                subActivities: [activity(title: "Inner step")]
            ),
        ]

        let failureActivity = ParsedActivity(
            title: "Synthetic.swift:42: assertion failed",
            isFailure: true,
            start: Date(timeIntervalSince1970: 1),
            attachments: [pngAttachment()],
            subActivities: []
        )

        let group = ParsedGroup(
            name: "SyntheticSuite",
            identifier: "SyntheticSuite",
            duration: 6,
            children: [
                .testCase(testCase(
                    name: "testPasses()",
                    iterations: [iteration(
                        number: nil,
                        status: .passed,
                        activities: standardActivities
                    )]
                )),
                .testCase(testCase(
                    name: "testFails()",
                    iterations: [iteration(
                        number: nil,
                        status: .failed,
                        activities: standardActivities + [failureActivity]
                    )]
                )),
                .testCase(testCase(
                    name: "testSkips()",
                    iterations: [iteration(number: nil, status: .skipped, activities: [])]
                )),
                .testCase(testCase(
                    name: "testExpectedlyFails()",
                    iterations: [iteration(
                        number: nil,
                        status: .expectedFailure,
                        activities: [failureActivity]
                    )]
                )),
                .testCase(testCase(
                    name: "testRetries()",
                    iterations: [
                        iteration(number: 1, status: .failed, activities: [failureActivity]),
                        iteration(number: 2, status: .passed, activities: standardActivities),
                    ]
                )),
            ]
        )

        return ParsedRun(
            destination: ParsedDestination(
                displayName: "Synthetic Device",
                deviceIdentifier: "00000000-0000-0000-0000-000000000000",
                modelName: "Synthetic Model",
                operatingSystemVersion: "1.0"
            ),
            logReference: logReference,
            testables: [ParsedTestable(targetName: "SyntheticTests", groups: [group])]
        )
    }

    static var parsedResult: ParsedResult {
        ParsedResult(runs: [parsedRun])
    }
}
