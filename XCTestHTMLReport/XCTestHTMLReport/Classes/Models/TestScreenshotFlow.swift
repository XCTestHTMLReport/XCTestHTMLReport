//
//  TestScreenshotFlow.swift
//  XCTestHTMLReport
//
//  Created by Alistair Leszkiewicz on 11/10/18.
//  Copyright © 2018 Tito. All rights reserved.
//

import Foundation

struct TestScreenshotFlow
{
    var screenshots: [ScreenshotAttachment]
    
    init?(activities: [Activity]?) {
        guard let activities = activities else {
            return nil
        }
        
        let anyScreenshots = activities.trueForAny { !$0.screenshotAttachments.isEmpty }
        guard anyScreenshots else {
            return nil
        }
        screenshots = activities.flatMap { $0.screenshotAttachments.map { ScreenshotAttachment(attachment: $0) } }
    }
    
}

fileprivate extension Sequence {
    // Determines whether any element in the Array matches the conditions defined by the specified predicate.
    func trueForAny(_ predicate: (Element) -> Bool) -> Bool {
        return first(where: predicate) != nil
    }
}

fileprivate extension Activity {
    
    var screenshotAttachments: [Attachment] {
        return attachments?.compactMap({ $0 }).filter { $0.isScreenshot } ?? []
        + subScreenshotAttachments
    }
    
    var subScreenshotAttachments: [Attachment] {
        return subActivities?.compactMap({ $0 }).flatMap({ $0.screenshotAttachments }) ?? []
    }
}


struct ScreenshotAttachment: HTML {
    let attachment: Attachment
    
    static let screenshot = """
  <img class=\"preview-screenshot\" src=\"[[PATH]]/Attachments/[[FILENAME]]\" id=\"screenshot-[[FILENAME]]\"/>
  """
    
    var htmlTemplate: String {
        return ScreenshotAttachment.screenshot
    }

    var htmlPlaceholderValues: [String: String] {
        return [
            "PATH": attachment.path,
            "FILENAME": attachment.filename
        ]
    }
}
