//
//  AttachmentHelpers.swift
//  XCTestHTMLReport
//

import Foundation

/// MARK: - Helpers
/// Helpers for location attachments from result model objects

extension Summary {

    var allAttachments: [Attachment] {
        runs.map({ $0.allAttachments }).reduce([], +)
    }

}


extension Run {

    var screenshotAttachments: [Attachment] {
        allAttachments.filter { $0.isScreenshot }
    }

    var allAttachments: [Attachment] {
        allTests.map({ $0.allAttachments }).reduce([], +)
    }

}

extension TestSummary {

    var allAttachments: [Attachment] {
        tests.map({ $0.allAttachments }).reduce([], +)
    }

}

extension Test {

    var allAttachments: [Attachment] {
        activities.map({ $0.allAttachments }).reduce([], +)
    }

}

extension Activity {

    var screenshotAttachments: [Attachment] {
        return allAttachments.filter { $0.isScreenshot }
    }

    var allAttachments: [Attachment] {
        return attachments + subAttachments
    }

    var subAttachments: [Attachment] {
        return subActivities.map({ $0.allAttachments }).reduce([], +)
    }
}
