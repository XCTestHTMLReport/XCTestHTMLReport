//
//  Activity.swift
//  XCTestHTMLReport
//
//  Created by Titouan van Belle on 22.07.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation

struct Activity: HTML {
    /// Path-derived, like every other element id (#430). An activity uuid
    /// would have been a field only the legacy backend could populate; a path
    /// digest is backend-neutral and keeps renders byte-reproducible.
    let uuid: String
    let padding: Int
    let attachments: [Attachment]

    var title: String
    var subActivities: [Activity]
    /// All that survives of the legacy activity taxonomy — see "Deciding the
    /// model before the port", answer 2.
    let isFailure: Bool

    var hasGlobalAttachment: Bool {
        let hasDirectAttachment = !attachments.isEmpty
        let subActivitesHaveAttachments = subActivities
            .reduce(false) { $0 || $1.hasGlobalAttachment }
        return hasDirectAttachment || subActivitesHaveAttachments
    }

    var hasFailingSubActivities: Bool {
        failingActivityRecursive != nil
    }

    var failingActivity: Activity? {
        isFailure ? self : nil
    }

    var failingActivityRecursive: Activity? {
        subActivities.first(where: { $0.failingActivityRecursive != nil }) ?? failingActivity
    }

    var cssClasses: String {
        isFailure || hasFailingSubActivities ? "activity-assertion-failure" : ""
    }

    init(
        activity: ParsedActivity,
        identifierPath: IdentifierPath,
        file: PayloadProviding,
        padding: Int = 0,
        renderingMode: Summary.RenderingMode,
        downsizeImagesEnabled: Bool,
        downsizeScaleFactor: CGFloat
    ) {
        uuid = identifierPath.identifier
        title = activity.title
        isFailure = activity.isFailure
        subActivities = activity.subActivities.enumerated().map { index, sub in
            Activity(
                activity: sub,
                identifierPath: identifierPath.appending("activity\(index)"),
                file: file,
                padding: padding + 10,
                renderingMode: renderingMode,
                downsizeImagesEnabled: downsizeImagesEnabled,
                downsizeScaleFactor: downsizeScaleFactor
            )
        }
        attachments = activity.attachments.map { attachment in
            autoreleasepool {
                Attachment(
                    attachment: attachment,
                    file: file,
                    padding: padding + 16,
                    renderingMode: renderingMode,
                    downsizeImagesEnabled: downsizeImagesEnabled,
                    downsizeScaleFactor: downsizeScaleFactor
                )
            }
        }
        self.padding = padding
    }

    // PRAGMA MARK: - HTML

    var htmlTemplate = HTMLTemplates.activity

    var htmlPlaceholderValues: [String: String] {
        [
            "UUID": uuid,
            "TITLE": title.stringByEscapingXMLChars,
            "PAPER_CLIP_CLASS": hasGlobalAttachment ? "inline-block" : "none",
            "PADDING": (subActivities.isEmpty && attachments.isEmpty) ? String(padding + 18) :
                String(padding),
            "ACTIVITY_TYPE_CLASS": cssClasses,
            "HAS_SUB-ACTIVITIES_CLASS": (subActivities.isEmpty && attachments.isEmpty) ?
                "no-drop-down" : "",
            "SUB_ACTIVITY": subActivities.accumulateHTMLAsString,
            "ATTACHMENTS": attachments.accumulateHTMLAsString,
        ]
    }
}

extension Activity: ContainingAttachment {
    var screenshotAttachments: [Attachment] {
        allAttachments.filter(\.isScreenshot)
    }

    var allAttachments: [Attachment] {
        attachments + subAttachments
    }

    var subAttachments: [Attachment] {
        subActivities.map(\.allAttachments).reduce([], +)
    }
}
