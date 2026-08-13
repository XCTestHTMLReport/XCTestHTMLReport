//
//  AttachmentTypeTests.swift
//

import XCTest
@testable import XCTestHTMLReportCore

final class AttachmentTypeTests: XCTestCase {
    func testMapsExtensionsToTypes() {
        XCTAssertEqual(AttachmentType(filenameExtension: "png"), .png)
        XCTAssertEqual(AttachmentType(filenameExtension: "PNG"), .png)
        XCTAssertEqual(AttachmentType(filenameExtension: "jpeg"), .jpeg)
        XCTAssertEqual(AttachmentType(filenameExtension: "jpg"), .jpeg)
        XCTAssertEqual(AttachmentType(filenameExtension: "mp4"), .mp4)
        XCTAssertEqual(AttachmentType(filenameExtension: "txt"), .text)
        XCTAssertEqual(AttachmentType(filenameExtension: "log"), .log)
        XCTAssertEqual(AttachmentType(filenameExtension: "html"), .html)
        XCTAssertEqual(AttachmentType(filenameExtension: "htm"), .html)
        XCTAssertEqual(AttachmentType(filenameExtension: "gif"), .gif)
        XCTAssertEqual(AttachmentType(filenameExtension: "heic"), .heic)
        XCTAssertEqual(AttachmentType(filenameExtension: "zip"), .zip)
        XCTAssertEqual(AttachmentType(filenameExtension: "dat"), .data)
    }

    /// Both readers must land on the same type for the same attachment, which
    /// is what answer 4 of the design spec bought. No fixture assertion
    /// catches one drifting, because they run against different documents.
    func testLegacyUTIsAndModernFilenamesAgree() {
        let cases: [(uti: String, filename: String)] = [
            ("public.png", "shot_0_ABC.png"),
            ("public.jpeg", "shot_0_ABC.jpeg"),
            ("public.heic", "shot_0_ABC.heic"),
            ("com.compuserve.gif", "anim_0_ABC.gif"),
            ("public.mpeg-4", "rec_0_ABC.mp4"),
            ("public.plain-text", "log_0_ABC.txt"),
            ("com.apple.log", "log_0_ABC.log"),
            ("public.html", "page_0_ABC.html"),
            ("public.zip-archive", "bundle_0_ABC.zip"),
            ("public.data", "blob_0_ABC.dat"),
        ]
        for (uti, filename) in cases {
            let viaLegacy = LegacyResultReader
                .filenameExtension(forUTI: uti, filename: nil)
                .flatMap(AttachmentType.init(filenameExtension:))
            let viaModern = AttachmentType(
                filenameExtension: (filename as NSString).pathExtension
            )
            XCTAssertNotNil(viaModern, "\(filename) typed as unknown")
            XCTAssertEqual(viaLegacy, viaModern, "\(uti) vs \(filename)")
        }
    }

    /// An unrecognised or absent extension fails the initializer, which
    /// `Attachment.init` maps to `.unknown` — the same degradation the legacy
    /// UTI path produced for an unknown identifier.
    func testUnrecognisedExtensionIsNotTyped() {
        XCTAssertNil(AttachmentType(filenameExtension: "xyz"))
        XCTAssertNil(AttachmentType(filenameExtension: ""))
    }
}
