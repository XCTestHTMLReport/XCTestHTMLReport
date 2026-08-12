//
//  Activity.swift
//  XCTestHTMLReport
//
//  Created by Titouan van Belle on 22.07.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation

enum ActivityType: String {
    case unknwown = ""
    case intern = "com.apple.dt.xctest.activity-type.internal"
    case deleteAttachment = "com.apple.dt.xctest.activity-type.deletedAttachment"
    case assertionFailure = "com.apple.dt.xctest.activity-type.testAssertionFailure"
    case userCreated = "com.apple.dt.xctest.activity-type.userCreated"
    case attachementContainer = "com.apple.dt.xctest.activity-type.attachmentContainer"
    case skippedTest = "com.apple.dt.xctest.activity-type.skippedTest"

    var cssClass: String {
        switch self {
        case .intern:
            return "activity-internal"
        case .deleteAttachment:
            return "activity-delete-attachment"
        case .assertionFailure:
            return "activity-assertion-failure"
        case .userCreated:
            return "activity-user-created"
        case .skippedTest:
            return "activity-skipped-test"
        default:
            return ""
        }
    }
}

struct Activity: HTML {
    let uuid: String
    let padding: Int
    let attachments: [Attachment]
    let startTime: TimeInterval?
    let finishTime: TimeInterval?
    var totalTime: TimeInterval {
        if let start = startTime, let finish = finishTime {
            return finish - start
        }

        return 0.0
    }

    var title: String
    var subActivities: [Activity]
    var type: ActivityType?
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
        type == .assertionFailure ? self : nil
    }

    var failingActivityRecursive: Activity? {
        subActivities.first(where: { $0.failingActivityRecursive != nil }) ?? failingActivity
    }

    var cssClasses: String {
        var cls = ""
        if let type = type {
            cls += type.cssClass

            if type == .userCreated, hasFailingSubActivities {
                cls += " activity-assertion-failure"
            }
        }

        return cls
    }

    init(
        activity: ParsedActivity,
        file: PayloadProviding,
        padding: Int = 0,
        renderingMode: Summary.RenderingMode,
        downsizeImagesEnabled: Bool,
        downsizeScaleFactor: CGFloat
    ) {
        uuid = activity.transitionalUUID
        startTime = activity.start?.timeIntervalSince1970 ?? 0
        finishTime = activity.transitionalFinish?.timeIntervalSince1970 ?? 0
        title = activity.title
        type = activity.transitionalActivityType.flatMap(ActivityType.init(rawValue:))
        subActivities = activity.subActivities.map {
            Activity(
                activity: $0,
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
            "TIME": totalTime.formattedSeconds,
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
