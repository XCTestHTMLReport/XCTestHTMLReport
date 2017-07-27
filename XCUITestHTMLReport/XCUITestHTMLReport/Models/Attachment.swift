//
//  Attachment.swift
//  XCUITestHTMLReport
//
//  Created by Titouan van Belle on 22.07.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation

enum AttachmentType: String {
    case unknwown = ""
    case png = "public.png"
    case text = "public.plain-text"

    var cssClass: String {
        switch self {
        case .png:
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
    var filename: String
    var type: AttachmentType?

    init(dict: [String : Any]) {
        filename = dict["Filename"] as! String
        let typeRaw = dict["UniformTypeIdentifier"] as! String

        if let attachmentType = AttachmentType(rawValue: typeRaw) {
            type = attachmentType
        } else {
            Logger.warning("Attachment type is not supported: \(typeRaw). Skipping.")
        }
    }

    // PRAGMA MARK: - HTML

    var htmlTemplate: String {
        if let type = type {
            switch type {
            case .png:
                return HTMLTemplates.screenshot
            case .text:
                return HTMLTemplates.text
            case .unknwown:
                return ""
            }
        }

        return ""
    }

    var htmlPlaceholderValues: [String: String] {
        if let type = type {
            switch type {
            case .png:
                return [
                    "FILENAME": filename
                ]
            case .text:
                return [
                    "FILENAME": filename
                ]
            case .unknwown:
                return [String: String]()
            }
        }

        return [String: String]()
    }
}

