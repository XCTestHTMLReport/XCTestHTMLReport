//
//  Attachment.swift
//  XCTestHTMLReport
//
//  Created by Titouan van Belle on 22.07.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation
import UniformTypeIdentifiers
import XCResultKit

enum AttachmentType: String {
    case unknown = ""
    case gif = "com.compuserve.gif"
    case data = "public.data"
    case html = "public.html"
    case jpeg = "public.jpeg"
    case png = "public.png"
    case heic = "public.heic"
    case mp4 = "public.mpeg-4"
    case text = "public.plain-text"
    case log = "com.apple.log"
    // TODO: Use UTType instead of handling each mime
    case zip = "public.zip-archive"

    var isImage: Bool {
        [.jpeg, .png, .heic].contains(self)
    }

    var isVideo: Bool {
        [.mp4].contains(self)
    }

    var isFile: Bool {
        [.text, .html, .data, .log].contains(self)
    }

    var cssClass: String {
        switch self {
        case .png, .jpeg, .heic:
            return "screenshot"
        case .mp4:
            return "video"
        case .text, .log:
            return "text"
        case .gif:
            return "gif"
        default:
            return ""
        }
    }

    fileprivate var mimeType: String? {
        if #available(macOS 11.0, *) {
            if let systemType = UTType(rawValue),
               let mimeType = systemType.preferredMIMEType
            {
                return mimeType
            }
        }

        switch self {
        case .png:
            return "image/png"
        case .gif:
            return "image/gif"
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
        case .zip:
            return "application/zip"
        case .unknown:
            return nil
        }
    }
}

enum AttachmentName: RawRepresentable {
    enum Constant: String {
        case kXCTAttachmentLegacyScreenImageData
    }

    case constant(Constant)
    case custom(String)

    var rawValue: String {
        switch self {
        case let .constant(constant):
            return constant.rawValue
        case let .custom(rawValue):
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

struct Attachment: HTML {
    let padding: Int
    let filename: String
    let content: RenderingContent
    let type: AttachmentType
    let name: AttachmentName?

    init(
        attachment: ActionTestAttachment,
        file: ResultFile,
        padding: Int = 0,
        renderingMode: Summary.RenderingMode,
        downsizeImagesEnabled: Bool,
        downsizeScaleFactor: CGFloat
    ) {
        filename = attachment.filename ?? ""
        type = AttachmentType(rawValue: attachment.uniformTypeIdentifier) ?? .unknown
        name = attachment.name.map(AttachmentName.init(rawValue:))
        self.padding = padding
        var content: RenderingContent = .none
        if let id = attachment.payloadRef?.id {
            content = file.exportPayloadContent(
                id: id,
                renderingMode: renderingMode,
                fileName: attachment.filename
            )
            if downsizeImagesEnabled, type.isImage {
                do {
                    if case let .url(url) = content {
                        // At this point, `url` is relative, this will break if the cwd is different
                        // from the xcresult path
                        // As a workaround, the absolute URL is reconstructed
                        content = try RenderingContent.downsizeFrom(.url(
                            file.url.deletingLastPathComponent()
                                .appendingPathComponent(url.relativeString)
                        ), downsizeScaleFactor: downsizeScaleFactor)
                    } else {
                        content = try RenderingContent.downsizeFrom(content, downsizeScaleFactor: downsizeScaleFactor)
                    }
                } catch {
                    Logger.error("Image resize failed with error: \(error.localizedDescription)")
                }
            }
        }
        self.content = content
    }

    var fallbackDisplayName: String {
        switch type {
        case .png, .jpeg, .heic:
            return "Screenshot"
        case .gif:
            return "Gif"
        case .mp4:
            return "Video"
        case .text, .html, .data, .log, .zip:
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
        case let .some(.custom(customName)):
            return customName
        default:
            return fallbackDisplayName
        }
    }

    var isScreenshot: Bool {
        type.isImage
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
        case .zip, .unknown:
            return HTMLTemplates.link // If not known, link/download the resource
        case .gif:
            return HTMLTemplates.gif
        }
    }

    var htmlPlaceholderValues: [String: String] {
        [
            "PADDING": String(padding),
            "SOURCE": source ?? "",
            "FILENAME": filename,
            "NAME": displayName,
        ]
    }
}
