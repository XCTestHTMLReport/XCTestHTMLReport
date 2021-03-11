//
//  Attachment.swift
//  XCTestHTMLReport
//
//  Created by Titouan van Belle on 22.07.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation
import XCResultKit

enum AttachmentType: String {
    case unknown = ""
    case data = "public.data"
    case html = "public.html"
    case jpeg = "public.jpeg"
    case png = "public.png"
    case heic = "public.heic"
    case mp4 = "public.mpeg-4"
    case text = "public.plain-text"
    case log = "com.apple.log"

    var cssClass: String {
        switch self {
        case .png, .jpeg, .heic:
            return "screenshot"
        case .mp4:
            return "video"
        case .text, .log:
            return "text"
        default:
            return ""
        }
    }

    fileprivate var mimeType: String? {
        switch self {
        case .png:
            return "image/png"
        case .jpeg:
            return "image/jpeg"
        case .heic:
            return "image/heic"
        case .text, .log:
            return "text/plain"
        case .mp4:
            return "video/mp4"
        case .html:
            return "text/html"
        case .data:
            return "application/octet-stream"
        case .unknown:
            return nil
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
    let padding: Int
    let filename: String
    let content: RenderingContent
    let type: AttachmentType
    let name: AttachmentName?

    init(attachment: ActionTestAttachment, file: ResultFile, padding: Int = 0, renderingMode: Summary.RenderingMode) {
        self.filename = attachment.filename ?? ""
        self.type = AttachmentType(rawValue: attachment.uniformTypeIdentifier) ?? .unknown
        self.name = attachment.name.map(AttachmentName.init(rawValue:))
        if let id = attachment.payloadRef?.id {
            self.content = file.exportPayloadContent(
                id: id,
                renderingMode: renderingMode
            )
        } else {
            self.content = .none
        }
        self.padding = padding
    }

    var fallbackDisplayName: String {
        switch type {
        case .png, .jpeg, .heic:
            return "Screenshot"
        case .mp4:
            return "Video"
        case .text, .html, .data, .log:
            return "File"
        case .unknown:
            return "Attachment"
        }
    }

    var source: String? {
        switch content {
        case let .data(data):
            guard let mimeType = type.mimeType else {
                return nil
            }
            return "data:\(mimeType);base64,\(data.base64EncodedString())"
        case let .url(url):
            return url.relativePath
        case .none:
            return nil
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

    var isScreenshot: Bool {
        switch type {
        case .png, .jpeg, .heic:
            return true
        default:
            return false
        }
    }
    
    // PRAGMA MARK: - HTML

    var htmlTemplate: String {
        switch type {
        case .png, .jpeg, .heic:
            return HTMLTemplates.screenshot
        case .mp4:
            return HTMLTemplates.video
        case .text, .html, .data, .log:
            return HTMLTemplates.text
        case .unknown:
            return ""
        }
    }

    var htmlPlaceholderValues: [String: String] {
        return [
            "PADDING": String(padding),
            "SOURCE": source ?? "",
            "FILENAME": filename,
            "NAME": displayName
        ]
    }
}

