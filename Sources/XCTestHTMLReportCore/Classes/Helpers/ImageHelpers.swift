//
//  ImageHelpers.swift
//  XCTestHTMLReport
//

import Foundation
import Cocoa

let imageWidth: CGFloat = 200
let imageCompression: Float = 0.8

/// Performs an image resize for the image at the provided path
/// image is resized to be 200px width - aspect ratio maintaned
/// and compressed using jpeg
/// If the image is already smaller than compression size it
/// is not modified
///
/// - Parameter path: path to an image
func resizeImage(atPath path: String) -> Bool {
    guard let image = NSImage(contentsOfFile: path) else {
        return false
    }
    let sizeRatio = imageWidth/image.size.width
    guard sizeRatio<1.0 else {
        return false
    }
    let resizedImage = resize(image: image,
                              w: Int(image.size.width*sizeRatio),
                              h: Int(image.size.height*sizeRatio))
    let destinationURL = URL(fileURLWithPath: path)
    resizedImage.jpegWrite(to: destinationURL, options: .atomic, compression: imageCompression)
    return true
}

func resize(image: NSImage, w: Int, h: Int) -> NSImage {
    let destSize = NSMakeSize(CGFloat(w), CGFloat(h))
    let newImage = NSImage(size: destSize)
    newImage.lockFocus()
    image.draw(in: NSMakeRect(0, 0, destSize.width, destSize.height), from: NSMakeRect(0, 0, image.size.width, image.size.height), operation: NSCompositingOperation.sourceOver, fraction: CGFloat(1))
    newImage.unlockFocus()
    newImage.size = destSize
    return NSImage(data: newImage.tiffRepresentation!)!
}

extension NSImage {

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
