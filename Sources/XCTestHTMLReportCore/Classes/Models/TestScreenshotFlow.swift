//
//  TestScreenshotFlow.swift
//  XCTestHTMLReport
//

import Foundation

struct TestScreenshotFlow {
    var screenshots: [ScreenshotFlowAttachment]
    var screenshotsTail: [ScreenshotFlowAttachment]

    init?(activities: [Activity]?, tailCount _: Int = 3) {
        guard let activities else {
            return nil
        }

        let anyScreenshots = activities.trueForAny { !$0.screenshotAttachments.isEmpty }
        guard anyScreenshots else {
            return nil
        }
        screenshots = activities
            .flatMap {
                $0.screenshotAttachments
                    .map { ScreenshotFlowAttachment(attachment: $0, className: "screenshot-flow") }
            }
        screenshotsTail = activities
            .flatMap {
                $0.screenshotAttachments
                    .map { ScreenshotFlowAttachment(attachment: $0, className: "screenshot-tail") }
            }
            .suffix(3)
    }
}

private extension Sequence {
    // Determines whether any element in the Array matches the conditions defined by the specified
    // predicate.
    func trueForAny(_ predicate: (Element) -> Bool) -> Bool {
        first(where: predicate) != nil
    }
}

struct ScreenshotFlowAttachment: HTML {
    let attachment: Attachment
    let className: String

    var htmlTemplate: String {
        "<img class=\"\(className)\" src=\"[[SRC]]\" id=\"screenshot-[[FILENAME]]\"/>"
    }

    var htmlPlaceholderValues: [String: String] {
        [
            "SRC": attachment.source ?? "",
            "FILENAME": attachment.filename,
        ]
    }
}
