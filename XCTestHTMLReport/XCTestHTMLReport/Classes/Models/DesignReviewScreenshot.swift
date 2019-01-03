//
//  DesignReviewScreenshot.swift
//  XCTestHTMLReport
//
//  Created by Julien Rollet on 26/12/2018.
//  Copyright © 2018 Tito. All rights reserved.
//

import Foundation

struct DesignReviewScreenshot: HTML
{
    private struct Constants {
        static let defaultName = "kXCTAttachmentLegacyScreenImageData"
    }

    var filename: String
    var path: String
    var name: String?

    init?(screenshotsPath: String, dict: [String : Any])
    {
        path = screenshotsPath
        filename = dict["Filename"] as! String
        name = dict["Name"] as? String

        let typeRaw = dict["UniformTypeIdentifier"] as! String
        guard isAllowed(typeRaw) else { return nil }
    }

    var fallbackDisplayName: String {
        return "Screenshot"
    }

    var displayName: String {
        guard let name = self.name else { return fallbackDisplayName }
        return name
    }

    // PRAGMA MARK: - HTML

    var htmlTemplate: String {
        return HTMLTemplates.designReviewScreenshot
    }

    var htmlPlaceholderValues: [String: String] {
        return [
            "PATH": path,
            "FILENAME": filename,
            "NAME": displayName
        ]
    }

    // PRAGMA MARK: - Private

    private func isAllowed(_ rawType: String) -> Bool {
        return (rawType == "public.jpeg" || rawType == "public.png")
            && name != Constants.defaultName
    }
}

