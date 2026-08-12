//
//  Iteration.swift
//
//
//  Created by Tyler Vick on 12/27/21.
//

import Foundation

struct Iteration: Test {
    /// Assigned by the owning `TestCase`, which is the only place that knows
    /// this iteration's final position among its siblings.
    let uuid: String

    let title: String
    let identifier: String
    let nodeKind: NodeKind = .testCase // TODO: Modify html template
    let duration: TimeInterval
    let status: Status
    let activities: [Activity]
    /// 1-based repetition number, `nil` when the backend reports none.
    let iterationNumber: Int?

    var testScreenshotFlow: TestScreenshotFlow? {
        TestScreenshotFlow(activities: activities)
    }

    init(
        iteration: ParsedIteration,
        uuid: String,
        title: String,
        identifier: String,
        file: PayloadProviding,
        renderingMode: Summary.RenderingMode,
        downsizeImagesEnabled: Bool,
        downsizeScaleFactor: CGFloat
    ) {
        self.uuid = uuid
        self.title = title
        self.identifier = identifier
        status = Status(iteration.status)
        duration = iteration.duration
        iterationNumber = iteration.iterationNumber
        // The reader already interleaved failure rows among the activities, so
        // this is a straight one-to-one mapping. Failure rows render one
        // indentation level shallower than regular activities — the old
        // failure-summary initializer defaulted its padding to 0 where
        // activity summaries were given 20 — and that rendered fact survives
        // the port.
        activities = iteration.activities.map {
            Activity(
                activity: $0,
                file: file,
                padding: $0.isFailure ? 0 : 20,
                renderingMode: renderingMode,
                downsizeImagesEnabled: downsizeImagesEnabled,
                downsizeScaleFactor: downsizeScaleFactor
            )
        }
    }
}

extension Iteration {
    var htmlPlaceholderValues: [String: String] {
        [
            "UUID": uuid,
            "TITLE": "Iteration \(iterationNumber ?? 0)",
            "DURATION": duration.formattedSeconds,
            "ICON_CLASS": status.cssClass,
            "SCREENSHOT_FLOW": testScreenshotFlow?.screenshots.accumulateHTMLAsString ?? "",
            "ACTIVITIES": activities.accumulateHTMLAsString,
        ]
    }

    var htmlTemplate: String {
        HTMLTemplates.iteration
    }
}

extension Iteration: ContainingAttachment {
    var allAttachments: [Attachment] {
        activities.map(\.allAttachments).reduce([], +)
    }
}
