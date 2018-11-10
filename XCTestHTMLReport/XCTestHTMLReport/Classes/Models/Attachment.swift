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

enum AttachmentName: RawRepresentable {
    enum Constant: String {
        case kXCTAttachmentLegacyScreenImageData = "kXCTAttachmentLegacyScreenImageData"
    }
    
    case constant(Constant)
    case custom(String)
    
    var rawValue: String {
        switch self {
        case .constant(let constant):
            return constant.rawValue
        case .custom(let rawValue):
            return rawValue
        }
    }
    
    init(rawValue: String) {
        guard let constant = Constant(rawValue: rawValue) else {
            self = .custom(rawValue)
            return
        }
        
        self = .constant(constant)
    }
}

struct Attachment: HTML
{
    var padding = 0
    var filename: String
    var path: String
    var type: AttachmentType?
    var name: AttachmentName?

    init(screenshotsPath: String, dict: [String : Any], padding: Int)
    {
        path = screenshotsPath
        filename = dict["Filename"] as! String
        let typeRaw = dict["UniformTypeIdentifier"] as! String

        if let attachmentType = AttachmentType(rawValue: typeRaw) {
            type = attachmentType
        } else {
            Logger.warning("Attachment type is not supported: \(typeRaw). Skipping.")
        }
        
        if let name = dict["Name"] as? String {
            self.name = AttachmentName(rawValue: name)
        }

        self.padding = padding
    }

    var isScreenshot: Bool {
        if let type = type {
            switch type {
            case .png, .jpeg:
                return true
            default:
                return false
            }
        }
        return false
    }

    var fallbackDisplayName: String {
        guard let type = type else { return "Attachment" }
        
        switch type {
        case .png, .jpeg:
            return "Screenshot"
        case .text, .html, .data:
            return "File"
        case .unknwown:
            return "Attachment"
        }
    }
    
    var displayName: String {
        switch name {
        case .some(.custom(let customName)):
            return customName
        default:
            return fallbackDisplayName
        }
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
            "FILENAME": filename,
            "NAME": displayName
        ]
    }
}

