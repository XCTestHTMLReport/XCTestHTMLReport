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
        default:
            return ""
        }
    }
}

struct Activity: HTML
{
    var uuid: String
    var padding = 0
    var attachments: [Attachment]?
    var startTime: TimeInterval?
    var finishTime: TimeInterval?
    var totalTime: TimeInterval {
        if let start = startTime, let finish = finishTime {
            return finish - start
        }

        return 0.0
    }
    var title: String
    var subActivities: [Activity]?
    var type: ActivityType?
    var hasGlobalAttachment: Bool {
        let hasDirecAttachment = attachments?.count ?? 0 > 0
        let subActivitesHaveAttachments = subActivities?.reduce(false) { $0 || $1.hasGlobalAttachment } ?? false
        return hasDirecAttachment || subActivitesHaveAttachments
    }
    
    init(root: String, dict: [String : Any], padding: Int) {
        uuid = dict["UUID"] as! String
        startTime = dict["StartTimeInterval"] as? TimeInterval
        finishTime = dict["FinishTimeInterval"] as? TimeInterval
        title = dict["Title"] as! String

        let rawActivityType = dict["ActivityType"] as! String
        if let activityType = ActivityType(rawValue: rawActivityType) {
            type = activityType
        } else {
            Logger.warning("Activity type is not supported: \(rawActivityType). Skipping activity: \(title)")
        }

        if let rawAttachments = dict["Attachments"] as? [[String : Any]] {
            attachments = rawAttachments.map { Attachment(root: root, dict: $0, padding: padding + 16) }
        }

        if let rawSubActivities = dict["SubActivities"] as? [[String : Any]] {
            subActivities = rawSubActivities.map { Activity(root: root, dict: $0, padding: padding + 10) }
        }

        self.padding = padding
    }

    // PRAGMA MARK: - HTML

    var htmlTemplate = HTMLTemplates.activity

    var htmlPlaceholderValues: [String: String] {
        return [
            "UUID": uuid,
            "TITLE": title,
            "PAPER_CLIP_CLASS": hasGlobalAttachment ? "inline-block" : "none",
            "PADDING": (subActivities == nil && (attachments == nil || attachments?.count == 0)) ? String(padding + 18) : String(padding),
            "TIME": totalTime.timeString,
            "ACTIVITY_TYPE_CLASS": type?.cssClass ?? "",
            "HAS_SUB-ACTIVITIES_CLASS": (subActivities == nil && (attachments == nil || attachments?.count == 0)) ? "no-drop-down" : "",
            "SUB_ACTIVITY": subActivities?.reduce("", { (accumulator: String, activity: Activity) -> String in
                return accumulator + activity.html
            }) ?? "",
            "ATTACHMENTS": attachments?.reduce("", { (accumulator: String, attachment: Attachment) -> String in
                return accumulator + attachment.html
            }) ?? "",
        ]
    }
}
