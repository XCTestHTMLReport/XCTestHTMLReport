//
//  Attachment.swift
//  XCTestHTMLReport
//
//  Created by Titouan van Belle on 22.07.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation

enum AttachmentType: String {
    case unknwown = ""
    case data = "public.data"
    case html = "public.html"
    case jpeg = "public.jpeg"
    case png = "public.png"
    case text = "public.plain-text"

    var cssClass: String {
        switch self {
        case .png, .jpeg:
            return "screenshot"
        case .text:
            return "text"
        default:
            return ""
        }
    }
}

struct Attachment: HTML
{
    var padding = 0
    var filename: String
    var path: String
    var type: AttachmentType?

    init(root: String, dict: [String : Any], padding: Int)
    {
        path = root
        filename = dict["Filename"] as! String
        let typeRaw = dict["UniformTypeIdentifier"] as! String

        if let attachmentType = AttachmentType(rawValue: typeRaw) {
            type = attachmentType
        } else {
            Logger.warning("Attachment type is not supported: \(typeRaw). Skipping.")
        }

        self.padding = padding
    }

    // PRAGMA MARK: - HTML

    var htmlTemplate: String {
        if let type = type {
            switch type {
            case .png, .jpeg:
                return HTMLTemplates.screenshot
            case .text, .html, .data:
                return HTMLTemplates.text
            case .unknwown:
                return ""
            }
        }

        return ""
    }

    var htmlPlaceholderValues: [String: String] {
        return [
            "PADDING": String(padding),
            "PATH": path,
            "FILENAME": filename
        ]
    }
}

