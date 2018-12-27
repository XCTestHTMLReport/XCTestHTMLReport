//
//  TestDesignReview.swift
//  XCTestHTMLReport
//
//  Created by Julien Rollet on 26/12/2018.
//  Copyright © 2018 Tito. All rights reserved.
//

import Foundation

struct TestDesignReview: HTML
{
    let uuid: String
    let screenshotsPath: String
    var screenshots: [DesignReviewScreenshot]

    init(screenshotsPath: String, dict: [String : Any])
    {
        uuid = NSUUID().uuidString
        self.screenshotsPath = screenshotsPath
        screenshots = []
        screenshots.append(contentsOf: populateScreenshots(from: dict))
    }

    // PRAGMA MARK: - HTML

    var htmlTemplate = HTMLTemplates.testDesignReview

    var htmlPlaceholderValues: [String: String] {
        return [
            "UUID": uuid,
            "DESIGN_REVIEW_SCREENSHOTS": screenshots.map { $0.html }.joined(),
        ]
    }

    // PRAGMA MARK: - Private

    private func populateScreenshots(from dict: [String : Any]) -> [DesignReviewScreenshot] {
        let rawTests = dict["Tests"] as! [[String: Any]]
        var allScreenshots = reduceIntoScreenshots(
            rawTests, exploringFunction: self.extractScreenshots(from:)
        )
        allScreenshots.sort {
            $0.displayName.compare($1.displayName, options: .numeric) == .orderedAscending
        }
        return allScreenshots
    }

    private func extractScreenshots(from dict: [String: Any]) -> [DesignReviewScreenshot] {
        var extractedScreenshots: [DesignReviewScreenshot] = []

        if let rawSubTests = dict["Subtests"] as? [[String : Any]] {
            let subTestsScreenshots = reduceIntoScreenshots(
                rawSubTests, exploringFunction: self.extractScreenshots(from:)
            )
            extractedScreenshots.append(contentsOf: subTestsScreenshots)
        }

        if let rawActivities = dict["ActivitySummaries"] as? [[String : Any]] {
            let activitiesScreenshots = reduceIntoScreenshots(
                rawActivities, exploringFunction: self.extractScreenshots(fromActivity:)
            )
            extractedScreenshots.append(contentsOf: activitiesScreenshots)
        }
        return extractedScreenshots
    }

    private func extractScreenshots(fromActivity activity: [String: Any]) -> [DesignReviewScreenshot] {
        var extractedScreenshots: [DesignReviewScreenshot] = []

        if let rawAttachments = activity["Attachments"] as? [[String : Any]] {
            let screenshots = rawAttachments.compactMap {
                DesignReviewScreenshot(screenshotsPath: screenshotsPath, dict: $0)
            }
            extractedScreenshots.append(contentsOf: screenshots)
        }

        if let rawSubActivities = activity["SubActivities"] as? [[String : Any]] {
            let subActivitiesScreenshots = reduceIntoScreenshots(
                rawSubActivities, exploringFunction: self.extractScreenshots(fromActivity:)
            )
            extractedScreenshots.append(contentsOf: subActivitiesScreenshots)
        }
        return extractedScreenshots
    }

    private func reduceIntoScreenshots(_ dicts: [[String : Any]],
                                       exploringFunction: ([String : Any]) -> [DesignReviewScreenshot]) -> [DesignReviewScreenshot] {
        return dicts.reduce([]) {
            var accumulatedScreenshots: [DesignReviewScreenshot] = []
            accumulatedScreenshots.append(contentsOf: $0)
            accumulatedScreenshots.append(contentsOf: exploringFunction($1))
            return accumulatedScreenshots
        }
    }
}
