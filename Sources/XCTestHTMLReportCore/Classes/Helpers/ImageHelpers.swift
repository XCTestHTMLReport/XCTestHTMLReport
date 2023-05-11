//
//  ImageHelpers.swift
//  XCTestHTMLReport
//

import Cocoa
import Foundation

enum ResizeError: Error {
    case largerThanOriginal
    case contentNotImage
    case imageFileNotFound
    case imageEncodingFailed
}

extension RenderingContent {
    static let imageCompression: Float = 0.8

    static func downsizeFrom(_ content: RenderingContent, downsizeScaleFactor: CGFloat) throws -> RenderingContent {
        switch content {
        case let .data(data):
            return .data(try RenderingContent.resize(content: data, downsizeScaleFactor: downsizeScaleFactor))
        case let .url(url):
            return .url(try RenderingContent.resize(content: url, downsizeScaleFactor: downsizeScaleFactor))
        case .none:
            throw ResizeError.contentNotImage
        }
    }
    
    /// Performs an  resize for the image data, scaling to 0.25 of the size while maintaining aspect ratio
    /// - Parameter content: NSImageResizable-conforming object, typically Data
    /// - Returns: A representation of the resized image
    private static func resize<C: NSImageResizable>(content: C, downsizeScaleFactor: CGFloat) throws -> C {
        let image = try content.asNSImage()
        let originalSize = image.size
        let newSize = CGSize(width: originalSize.width * downsizeScaleFactor, height: originalSize.height * downsizeScaleFactor)

        let newImage = NSImage(size: newSize, flipped: false) { rect in
            image.draw(in: rect,
                       from: CGRect(origin: .zero, size: originalSize),
                       operation: .copy,
                       fraction: 1)
            return true
        }

        return try C.from(content: content, image: newImage)
    }
}

protocol NSImageResizable {
    associatedtype Format = Self

    func asNSImage() throws -> NSImage

    static func from(content: Self, image: NSImage) throws -> Self
}

extension Data: NSImageResizable {
    static func from(content _: Data, image: NSImage) throws -> Data {
        guard let data = image.jpegData(compression: RenderingContent.imageCompression) else {
            throw ResizeError.imageEncodingFailed
        }
        return data
    }

    func asNSImage() throws -> NSImage {
        guard let image = NSImage(data: self) else {
            throw ResizeError.contentNotImage
        }
        return image
    }
}

extension URL: NSImageResizable {
    static func from(content url: URL, image: NSImage) throws -> URL {
        try FileManager.default.removeItem(at: url)
        // Rewrite the URL from .heic to .jpeg
        let jpegUrl = url.deletingPathExtension().appendingPathExtension("jpeg")
        try image.jpegData(compression: RenderingContent.imageCompression)?
            .write(to: jpegUrl, options: .atomic)
        // Do our best to return url relative to xcresult for portability
        if let newRelativeUrl = URL(
            string: Array(jpegUrl.pathComponents.suffix(2))
                .joined(separator: "/")
        ) {
            return newRelativeUrl
        }
        return url
    }

    func asNSImage() throws -> NSImage {
        guard let image = NSImage(contentsOf: self) else {
            throw ResizeError.imageFileNotFound
        }
        return image
    }
}

extension NSImage {
    static func from(image: NSImage, scaledTo newSize: CGSize) -> NSImage {
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: image.size),
            operation: .sourceOver,
            fraction: 1
        )
        newImage.unlockFocus()
        return newImage
    }

    func jpegData(compression: Float) -> Data? {
        guard let tiffRepresentation = tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffRepresentation)
        else {
            return nil
        }
        return bitmapImage.representation(
            using: .jpeg,
            properties: [NSBitmapImageRep.PropertyKey
                .compressionFactor: NSNumber(value: compression)]
        )
    }

    @discardableResult
    func jpegWrite(
        to url: URL,
        options: Data.WritingOptions = .atomic,
        compression: Float
    ) -> Bool {
        do {
            try jpegData(compression: compression)?.write(to: url, options: options)
            return true
        } catch {
            Logger.error("Image write error: " + error.localizedDescription)
            return false
        }
    }
}

extension CGSize: Comparable {
    public static func scaleFrom(_ size: CGSize, usingMaxWidth width: CGFloat) -> CGSize {
        let ratio = width / size.width
        return CGSize(width: size.width * ratio, height: size.height * ratio)
    }

    // Compares by area
    public static func < (lhs: CGSize, rhs: CGSize) -> Bool {
        (lhs.width * lhs.height) < (rhs.width * rhs.height)
    }
}
