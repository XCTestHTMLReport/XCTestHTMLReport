//
//  Iteration.swift
//
//
//  Created by Tyler Vick on 12/27/21.
//

import Foundation
import XCResultKit

struct Iteration: Test {
    let uuid = UUID().uuidString
    let title: String
    let identifier: String
    let objectClass: ObjectClass = .testSummary // TODO: Modify html template
    let duration: TimeInterval
    let status: Status
    let activities: [Activity]
    let repetitionPolicy: ActionTestRepetitionPolicySummary?

    var testScreenshotFlow: TestScreenshotFlow? {
        TestScreenshotFlow(activities: activities)
    }

    init(metadata: ActionTestMetadata, resultFile: ResultFile, renderingMode: Summary.RenderingMode) {
        title = metadata.name
        identifier = metadata.identifier
        status = Status(rawValue: metadata.testStatus) ?? .unknown
        duration = metadata.duration ?? 0

        if let id = metadata.summaryRef?.id,
           let actionTestSummary = resultFile.getActionTestSummary(id: id)
        {
            activities = actionTestSummary.activitySummaries.map {
                Activity(summary: $0, file: resultFile, padding: 20, renderingMode: renderingMode)
            }

            repetitionPolicy = actionTestSummary.repetitionPolicySummary
        } else {
            activities = []
            repetitionPolicy = nil
        }
    }
}

extension Iteration {
    var htmlPlaceholderValues: [String: String] { [
        "UUID": uuid,
        "TITLE": "Iteration \(repetitionPolicy?.iteration ?? 0)",
        "DURATION": duration.formattedSeconds,
        "ICON_CLASS": status.cssClass,
        "SCREENSHOT_FLOW": testScreenshotFlow?.screenshots.accumulateHTMLAsString ?? "",
        "ACTIVITIES": activities.accumulateHTMLAsString,
    ] }

    var htmlTemplate: String { HTMLTemplates.iteration }
}

extension Iteration: ContainingAttachment {
    var allAttachments: [Attachment] {
        activities.map(\.allAttachments).reduce([], +)
    }
}
