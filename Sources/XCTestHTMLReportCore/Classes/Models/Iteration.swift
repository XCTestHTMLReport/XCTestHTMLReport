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

    init(
        metadata: ActionTestMetadata,
        resultFile: ResultFile,
        renderingMode: Summary.RenderingMode,
        downsizeImagesEnabled: Bool
    ) {
        title = metadata.name
        identifier = metadata.identifier
        status = Status(rawValue: metadata.testStatus) ?? .unknown
        duration = metadata.duration ?? 0

        if let id = metadata.summaryRef?.id,
           let actionTestSummary = resultFile.getActionTestSummary(id: id)
        {
            let actionTestActivities = actionTestSummary.activitySummaries.map {
                Activity(
                    summary: $0,
                    file: resultFile,
                    padding: 20,
                    renderingMode: renderingMode,
                    downsizeImagesEnabled: downsizeImagesEnabled
                )
            }

            // As of xcresulttool 3.39, assertion failures are no longer listed within ActionTestActivitySummary.
            // This means that we need to interpolate ActionTestFailureSummaries alongside existing acitivities.
            // If ActionTestSummary already contains "failingSubActivities", it means that we're using xcresulttool < 3.39,
            // and we shouldn't evaluate ActionTestFailureSummaries to avoid duplicate failure statements.
            if actionTestActivities.first(where: { $0.hasFailingSubActivities }) != nil {
                activities = actionTestActivities
            } else {
                let actionTestFailureActivities = actionTestSummary.failureSummaries.map {
                    Activity(
                        failureSummary: $0,
                        file: resultFile,
                        renderingMode: renderingMode,
                        downsizeImagesEnabled: downsizeImagesEnabled
                    )
                }

                // Combine ActionTestActivity and ActionTestFailureActivity arrays together, sorted by the finishTime
                // TODO: We may want to insert the failure activity between subactivities
                activities = (actionTestActivities + actionTestFailureActivities).sorted(by: {
                    if let finishTime0 = $0.finishTime,
                       let finishTime1 = $1.finishTime
                    {
                        return finishTime0 < finishTime1
                    }
                    return true
                })
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
