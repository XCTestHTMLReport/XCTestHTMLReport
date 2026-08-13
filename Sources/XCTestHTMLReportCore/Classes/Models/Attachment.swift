//
//  Attachment.swift
//  XCTestHTMLReport
//
//  Created by Titouan van Belle on 22.07.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation
import UniformTypeIdentifiers

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

    /// The port carries a filename extension rather than a UTI (see "Deciding
    /// the model before the port", answer 4), so both backends type
    /// attachments from the same fact. `UTType(filenameExtension:)` would be
    /// the direct route but is macOS 11+ against a 10.15 floor, so the mapping
    /// is an explicit table like `mimeType`'s fallback below.
    init?(filenameExtension: String) {
        switch filenameExtension.lowercased() {
        case "png": self = .png
        case "jpg", "jpeg": self = .jpeg
        case "heic": self = .heic
        case "gif": self = .gif
        case "mp4": self = .mp4
        case "txt": self = .text
        case "log": self = .log
        case "html", "htm": self = .html
        case "zip": self = .zip
        case "dat": self = .data
        default: return nil
        }
    }

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

/// An attachment's name as the xcresult recorded it, split by whether a human
/// chose it.
///
/// XCTest fills the field in itself for attachments the framework creates —
/// `kXCTAttachmentScreenRecording`, `kXCTAttachmentLegacyScreenImageData` and
/// the rest of the `kXCT…` family — and those are internal identifiers, not
/// labels: the audit found `kXCTAttachmentScreenRecording` printed verbatim in
/// the UI where Xcode shows "Screen recording". Matching the whole family by
/// prefix rather than enumerating it means a constant Apple adds later is
/// caught the day it appears instead of the day someone notices it on screen.
///
/// The distinction is deliberately drawn from the name alone, which is a field
/// both backends have. Anything richer (asking whether the attachment came
/// from the screenshot machinery, say) exists only on legacy, and would make
/// the two backends label the same attachment differently.
enum AttachmentName: RawRepresentable {
    /// A name XCTest generated for itself. Never shown.
    case `internal`(String)
    /// A name the test author passed to `XCTAttachment.name`.
    case custom(String)

    private static let internalPrefix = "kXCT"

    var rawValue: String {
        switch self {
        case let .internal(rawValue), let .custom(rawValue):
            return rawValue
        }
    }

    init(rawValue: String) {
        self = rawValue.hasPrefix(Self.internalPrefix)
            ? .internal(rawValue)
            : .custom(rawValue)
    }
}

struct Attachment: HTML {
    let padding: Int
    let filename: String
    let content: RenderingContent
    let type: AttachmentType
    let name: AttachmentName?
    /// The payload this attachment was resolved from, kept so that a failure to
    /// resolve it can be reported against something identifiable.
    let payloadId: String?

    init(
        attachment: ParsedAttachment,
        file: PayloadProviding,
        padding: Int = 0,
        renderingMode: Summary.RenderingMode,
        downsizeImagesEnabled: Bool,
        downsizeScaleFactor: CGFloat
    ) {
        filename = attachment.filename ?? ""
        type = attachment.filenameExtension
            .flatMap(AttachmentType.init(filenameExtension:)) ?? .unknown
        name = attachment.name.map(AttachmentName.init(rawValue:))
        payloadId = attachment.payloadReference
        self.padding = padding
        var content: RenderingContent = .none
        if let id = attachment.payloadReference {
            content = file.exportPayloadContent(
                reference: id,
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
                        content = try RenderingContent.downsizeFrom(
                            content,
                            downsizeScaleFactor: downsizeScaleFactor
                        )
                    }
                } catch {
                    Logger.error("Image resize failed with error: \(error.localizedDescription)")
                }
            }
        }
        self.content = content
    }

    /// Whether this attachment represents a failure to resolve its payload.
    ///
    /// An attachment with no `payloadRef` has nothing to resolve: its content
    /// is `.none` by construction, which is not degradation (#387). Only a
    /// payload that existed and produced no content is a genuine failure.
    var failedToResolve: Bool {
        guard payloadId != nil else {
            return false
        }
        guard case .none = content else {
            return false
        }
        return true
    }

    /// How this attachment is named in a `Fault` detail.
    ///
    /// `filename` is empty for nameless attachments, which would otherwise
    /// produce a fault whose detail is the empty string.
    var faultDescription: String {
        if !filename.isEmpty {
            return filename
        }
        let label = name?.rawValue ?? fallbackDisplayName
        guard let payloadId else {
            return label
        }
        return "\(label) (payload id \(payloadId))"
    }

    /// The label an attachment carries when no human named it.
    ///
    /// Derived from `type`, which both backends set from the same fact (the
    /// payload's filename extension), so the same attachment reads the same
    /// on either — the one property this vocabulary has to have. Modern
    /// xcresults never carry a user-supplied name at all, so for them this
    /// is not a fallback, it is the label.
    var fallbackDisplayName: String {
        switch type {
        case .png, .jpeg, .heic:
            return "Screenshot"
        case .gif:
            // "Gif" was a file format shouted at the reader; the row is
            // already labelled by an image glyph and the extension is in the
            // preview link.
            return "Image"
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

    /// What the report prints for this attachment.
    ///
    /// A name only reaches the UI when a test author wrote it. Everything
    /// else — an unnamed attachment, or one XCTest named for itself — gets
    /// the type-derived label, so no `kXCT…` identifier can be rendered.
    var displayName: String {
        switch name {
        case let .some(.custom(customName)):
            return customName
        case .some(.internal), .none:
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
