//
//  Activity.swift
//  XCUITestHTMLReport
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
    var attachments: [Attachment]?
    var startTime: TimeInterval
    var finishTime: TimeInterval
    var hasScreenshotData: Bool?
    var title: String
    var subActivities: [Activity]?
    var type: ActivityType?
    
    init(dict: [String : Any]) {
        uuid = dict["UUID"] as! String
        startTime = dict["StartTimeInterval"] as! TimeInterval
        finishTime = dict["FinishTimeInterval"] as! TimeInterval
        title = dict["Title"] as! String
        hasScreenshotData = dict["HasScreenshotData"] as? Bool

        let rawActivityType = dict["ActivityType"] as! String
        if let activityType = ActivityType(rawValue: rawActivityType) {
            type = activityType
        } else {
            print("Activity type is not supported: \(rawActivityType)")
        }

        if let rawAttachments = dict["Attachments"] as? [[String : Any]] {
            attachments = rawAttachments.map { Attachment(dict: $0) }
        }

        if let rawSubActivities = dict["SubActivities"] as? [[String : Any]] {
            subActivities = rawSubActivities.map { Activity(dict: $0) }
        }
    }

    // PRAGMA MARK: - HTML

    var htmlTemplate = HTMLTemplates.activity

    var htmlPlaceholderValues: [String: String] {
        return [
            "UUID": uuid,
            "TITLE": title,
            "TIME": String(format: "%.2f", finishTime - startTime),
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
