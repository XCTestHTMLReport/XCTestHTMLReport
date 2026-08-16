//
//  DownsizeMemoryTests.swift
//
//  Guards the `autoreleasepool` in `Activity.init` (183be4d, #372) — one line
//  with no other test holding it down, and the difference between `-z` working
//  on a large report and the process being killed (#337).
//
//  Downsizing decodes each screenshot into an NSImage, renders it at the new
//  size, takes a TIFF representation of that, and encodes JPEG from the
//  representation. Those are autoreleased Cocoa objects: without a pool draining
//  them per attachment they live until the process exits, so peak memory tracks
//  total attachment count rather than the largest single image. Measured
//  through this very test, that is ~25 MB per screenshot retained — which is why
//  the reporter in #337 watched 2,532 screenshots climb past 100 GB before the
//  OOM killer took it, while the same flag worked fine on a small sample.
//
//  This test therefore asserts a *shape*, not a number: memory must not scale
//  with attachment count. The margin is enormous — roughly 0.06 MB per
//  attachment pooled against ~25 MB unpooled — so the threshold below sits far
//  above resident-size noise while still failing decisively if the pool goes.
//

import Cocoa
import XCTest
@testable import XCTestHTMLReportCore

final class DownsizeMemoryTests: XCTestCase {
    /// Attachments to render. Large enough that an unpooled run allocates
    /// gigabytes and cannot be mistaken for noise, small enough to keep the
    /// test near twenty seconds.
    private static let attachmentCount = 80

    /// iPhone-class retina dimensions: the size that made #337 fatal.
    private static let sourceWidth = 1290
    private static let sourceHeight = 2796
    private static let scaleFactor: CGFloat = 0.25

    private static let bytesPerMB: UInt64 = 1048576

    /// Per-attachment resident growth allowed. Two orders of magnitude above
    /// the pooled cost and a fifth of the unpooled cost, so neither allocator
    /// slack nor a busy CI machine can push it either way.
    private static let perAttachmentBudget: UInt64 = 5 * bytesPerMB

    struct ResidentSizeUnavailable: Error {
        let code: kern_return_t
    }

    /// Resident size of this process, which is what the OOM killer reads.
    /// Heap accounting would miss the Cocoa image buffers this is about.
    ///
    /// Throws rather than returning zero on failure: a zero here would make
    /// `after - before` zero too, and the test would report success having
    /// measured nothing at all.
    private func residentBytes() throws -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            throw ResidentSizeUnavailable(code: result)
        }
        return info.resident_size
    }

    /// A retina-sized screenshot, striped so JPEG cannot collapse it to a few
    /// bytes. A blank image would compress to nothing and decode to nothing,
    /// which would make the unpooled case look harmless and the guard useless.
    private func screenshot(width: Int, height: Int) -> Data? {
        let image = NSImage(size: CGSize(width: width, height: height))
        image.lockFocus()
        for column in stride(from: 0, to: width, by: 13) {
            NSColor(
                calibratedRed: CGFloat(column % 255) / 255.0,
                green: CGFloat((column * 7) % 255) / 255.0,
                blue: 0.6,
                alpha: 1
            ).setFill()
            NSRect(x: column, y: 0, width: 13, height: height).fill()
        }
        image.unlockFocus()
        return image.jpegData(compression: 0.9)
    }

    /// Proves the pooled path actually ran. Low memory is only evidence of a
    /// working pool if the images were really decoded and re-encoded; if
    /// downsizing silently became a no-op — the flag ignored, or
    /// `AttachmentType.isImage` no longer recognising the extension — the
    /// measurement would sail through while guarding nothing at all.
    private func assertWasDownsized(
        _ attachment: Attachment?,
        source: Data,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let rendered = try XCTUnwrap(attachment, file: file, line: line)
        guard case let .data(renderedData) = rendered.content else {
            return XCTFail(
                "inline rendering should have produced data content",
                file: file,
                line: line
            )
        }
        let renderedImage = try XCTUnwrap(NSImage(data: renderedData), file: file, line: line)
        XCTAssertEqual(
            renderedImage.size.width,
            CGFloat(Self.sourceWidth) * Self.scaleFactor,
            accuracy: 2,
            "attachment was not downsized, so the image path under test never ran",
            file: file,
            line: line
        )
        XCTAssertLessThan(
            renderedData.count,
            source.count,
            "downsized payload should be smaller than the source screenshot",
            file: file,
            line: line
        )
    }

    func testDownsizingDoesNotScaleMemoryWithAttachmentCount() throws {
        let reference = "payload-screenshot"
        let source = try XCTUnwrap(
            screenshot(width: Self.sourceWidth, height: Self.sourceHeight)
        )
        let provider = StubPayloadProvider(exports: [reference: source])

        let attachments = (0 ..< Self.attachmentCount).map { index in
            ParsedAttachment(
                name: "Screenshot \(index)",
                filename: "screenshot-\(index).jpeg",
                filenameExtension: "jpeg",
                payloadReference: reference
            )
        }
        let parsed = SyntheticResult.activity(title: "Screens", attachments: attachments)

        // Render one attachment first so one-time allocations — the JPEG
        // decoder, colour management, the graphics context — land before the
        // measurement rather than inside it.
        _ = Activity(
            activity: SyntheticResult.activity(
                title: "Warmup",
                attachments: [attachments[0]]
            ),
            identifierPath: IdentifierPath.root.appending("warmup"),
            file: provider,
            renderingMode: .inline,
            downsizeImagesEnabled: true,
            downsizeScaleFactor: Self.scaleFactor
        )

        let before = try residentBytes()
        let activity = Activity(
            activity: parsed,
            identifierPath: IdentifierPath.root.appending("measured"),
            file: provider,
            renderingMode: .inline,
            downsizeImagesEnabled: true,
            downsizeScaleFactor: Self.scaleFactor
        )
        let after = try residentBytes()

        // Keep the result alive across the measurement: inline rendering holds
        // each downsized payload by design, and that retention is part of what
        // is being bounded. Releasing it early would measure the wrong thing.
        XCTAssertEqual(activity.attachments.count, Self.attachmentCount)

        try assertWasDownsized(activity.attachments.first, source: source)

        let growth = after > before ? after - before : 0
        let perAttachment = growth / UInt64(Self.attachmentCount)
        XCTAssertLessThanOrEqual(
            perAttachment,
            Self.perAttachmentBudget,
            """
            Downsizing retained \(perAttachment / Self.bytesPerMB) MB per attachment \
            (\(growth / Self.bytesPerMB) MB across \(Self.attachmentCount)), above the \
            \(Self.perAttachmentBudget / Self.bytesPerMB) MB budget. Memory is scaling with \
            attachment count, which is #337: check that the autoreleasepool around \
            Attachment construction in Activity.init is still there.
            """
        )
    }
}
