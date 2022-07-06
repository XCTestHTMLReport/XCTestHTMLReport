//
//  ImageHelpers.swift
//  XCTestHTMLReport
//

import Foundation
import Cocoa


/// Performs an image resize for the image at the provided path
/// image is resized to be 200px width - aspect ratio maintaned
/// and compressed using jpeg
/// If the image is already smaller than compression size it
/// is not modified
///
/// - Parameter path: path to an image


enum ResizeError: Error {
    case largerThanOriginal
    case contentNotImage
    case imageFileNotFound
    case imageEncodingFailed
}

extension RenderingContent {
    static let downsizedWidth: CGFloat = 200
    static let imageCompression: Float = 0.8

    static func downsizeFrom(_ content: RenderingContent) throws -> RenderingContent {
        switch content {
        case .data(let data):
            return .data(try RenderingContent.resize(content: data))
        case .url(let url):
            return .url(try RenderingContent.resize(content: url))
        case .none:
            throw ResizeError.contentNotImage
        }
    }
    
    private static func resize<C: NSImageResizable>(content: C) throws -> C {
        let image = try content.asNSImage()
        let newSize = CGSize.scaleFrom(image.size, usingMaxWidth: downsizedWidth)
        let resizedImage = NSImage.from(image: image, scaledTo: newSize)
        return try C.from(content: content, image: resizedImage)
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
        try image.jpegData(compression: RenderingContent.imageCompression)?.write(to: url, options: .atomic)
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
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .sourceOver,
                   fraction: 1)
        newImage.unlockFocus()
        return newImage
    }

    func jpegData(compression: Float) -> Data? {
        guard let tiffRepresentation = tiffRepresentation, let bitmapImage = NSBitmapImageRep(data: tiffRepresentation) else { return nil }
        return bitmapImage.representation(using: .jpeg, properties: [ NSBitmapImageRep.PropertyKey.compressionFactor : NSNumber(value: compression)])
    }

    @discardableResult
    func jpegWrite(to url: URL, options: Data.WritingOptions = .atomic, compression: Float) -> Bool {
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
        return (lhs.width * lhs.height) < (rhs.width * rhs.height)
    }
}
