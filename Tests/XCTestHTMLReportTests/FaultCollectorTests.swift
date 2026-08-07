import Foundation
import XCTest
@testable import XCTestHTMLReportCore

final class FaultCollectorTests: XCTestCase {
    func testStartsEmpty() {
        let collector = FaultCollector()
        XCTAssertTrue(collector.isEmpty)
        XCTAssertEqual(collector.faults.count, 0)
    }

    func testRecordsFaultWithKindAndDetail() {
        let collector = FaultCollector()
        collector.record(.unresolvedAttachment, "attachment-1")

        XCTAssertFalse(collector.isEmpty)
        XCTAssertEqual(collector.faults.count, 1)
        XCTAssertEqual(collector.faults[0].kind, .unresolvedAttachment)
        XCTAssertEqual(collector.faults[0].detail, "attachment-1")
    }

    func testConcurrentRecordingDoesNotLoseFaults() {
        let collector = FaultCollector()
        let iterations = 1000

        DispatchQueue.concurrentPerform(iterations: iterations) { index in
            collector.record(.payloadExportFailed, "payload-\(index)")
        }

        XCTAssertEqual(collector.faults.count, iterations)
    }
}
