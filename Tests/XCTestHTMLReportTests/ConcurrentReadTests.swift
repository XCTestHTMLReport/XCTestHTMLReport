//
//  ConcurrentReadTests.swift
//
//  Pins the concurrent per-test reads restored for #162: they really overlap,
//  and overlapping them changes nothing a report or the CLI shows — rows keep
//  the tree's order, and faults are listed in that order too, whatever order
//  the reads finish in.
//
//  The legacy reader reads through XCResultKit's concrete `XCResultFile`, so
//  it has no seam to fake here; the differential and snapshot suites pin its
//  output on the fixtures instead.
//

import XCTest
@testable import XCTestHTMLReportCore

final class ConcurrentReadTests: XCTestCase {
    // MARK: - concurrentMap

    func testConcurrentMapKeepsSourceOrder() {
        let input = Array(0 ..< 200)
        let output = input.concurrentMap(width: 8) { value -> Int in
            // Later elements finish first, so completion order is the reverse
            // of source order wherever they overlap.
            usleep(useconds_t((200 - value) * 50))
            return value * 2
        }
        XCTAssertEqual(output, input.map { $0 * 2 })
    }

    func testConcurrentMapNeverExceedsItsWidth() {
        let lock = NSLock()
        var inFlight = 0
        var peak = 0
        _ = Array(0 ..< 40).concurrentMap(width: 3) { _ in
            lock.lock()
            inFlight += 1
            peak = max(peak, inFlight)
            lock.unlock()
            usleep(2000)
            lock.lock()
            inFlight -= 1
            lock.unlock()
        }
        XCTAssertLessThanOrEqual(peak, 3)
    }

    // MARK: - Modern reader

    /// Ten test cases across two suites, in a known tree order.
    private static let identifiers = (0 ..< 2).flatMap { suite in
        (0 ..< 5).map { "S\(suite)/t\($0)()" }
    }

    private static let testsJSON: String = {
        let suites = (0 ..< 2).map { suite -> String in
            let cases = (0 ..< 5).map { index in
                #"{"nodeType":"Test Case","name":"t\#(index)()","#
                    + #""nodeIdentifier":"S\#(suite)/t\#(index)()","result":"Passed"}"#
            }
            return #"{"nodeType":"Test Suite","name":"S\#(suite)","children":["#
                + cases.joined(separator: ",") + "]}"
        }
        return #"""
        {"devices":[{"deviceId":"D","deviceName":"Mac","modelName":"Mac","osVersion":"1.0"}],
         "testNodes":[{"nodeType":"Test Plan","name":"P","children":[
           {"nodeType":"Unit test bundle","name":"B","children":[\#(
               suites.joined(separator: ",")
           )]}]}]}
        """#
    }()

    private struct ActivitiesUnavailable: Error {}

    /// Answers the tests document, and fails every `activities` query after a
    /// delay that is longest for the first test in the tree — so if the reads
    /// overlap at all, they finish in roughly reverse order.
    private struct SlowFailingClient: XCResultToolInvoking {
        var bundleDescription: String {
            "Concurrent.xcresult"
        }

        func run(_: [String]) throws -> Data {
            Data()
        }

        func json<T: Decodable>(_ arguments: [String], as type: T.Type) throws -> T {
            guard arguments.contains("activities") else {
                return try JSONDecoder().decode(
                    type,
                    from: Data(ConcurrentReadTests.testsJSON.utf8)
                )
            }
            let identifier = arguments.last ?? ""
            let position = ConcurrentReadTests.identifiers.firstIndex(of: identifier) ?? 0
            usleep(useconds_t((ConcurrentReadTests.identifiers.count - position) * 3000))
            throw ActivitiesUnavailable()
        }
    }

    func testRowsAndFaultsKeepTreeOrderWhateverOrderReadsFinish() throws {
        for _ in 0 ..< 3 {
            let collector = FaultCollector()
            let result = try XCTUnwrap(ModernResultReader(
                client: SlowFailingClient(), payloadStore: nil, faultCollector: collector
            ).read())

            let rows = result.runs.flatMap(\.testables).flatMap(\.groups).flatMap { group in
                group.children.compactMap { node -> String? in
                    if case let .testCase(testCase) = node {
                        return testCase.identifier
                    }
                    return nil
                }
            }
            XCTAssertEqual(rows, Self.identifiers)
            XCTAssertEqual(
                collector.faults,
                Self.identifiers.map { Fault(kind: .missingActivities, detail: $0) },
                "Faults must be listed in tree order, not completion order"
            )
        }
    }

    /// Holds the first `activities` query until a second one arrives. A
    /// reader that reads one test at a time never sends the second, so the
    /// wait times out — which is the regression #162 describes.
    private final class RendezvousClient: XCResultToolInvoking {
        let lock = NSLock()
        let secondArrived = DispatchSemaphore(value: 0)
        var arrivals = 0
        var metOtherRead = false

        var bundleDescription: String {
            "Rendezvous.xcresult"
        }

        func run(_: [String]) throws -> Data {
            Data()
        }

        func json<T: Decodable>(_ arguments: [String], as type: T.Type) throws -> T {
            guard arguments.contains("activities") else {
                return try JSONDecoder().decode(
                    type,
                    from: Data(ConcurrentReadTests.testsJSON.utf8)
                )
            }
            lock.lock()
            arrivals += 1
            let arrival = arrivals
            lock.unlock()
            if arrival == 1 {
                let met = secondArrived.wait(timeout: .now() + 10) == .success
                lock.lock()
                metOtherRead = met
                lock.unlock()
            } else if arrival == 2 {
                secondArrived.signal()
            }
            throw ActivitiesUnavailable()
        }
    }

    func testModernReaderOverlapsPerTestReads() throws {
        let client = RendezvousClient()
        _ = try XCTUnwrap(ModernResultReader(
            client: client, payloadStore: nil, faultCollector: FaultCollector()
        ).read())
        client.lock.lock()
        defer { client.lock.unlock() }
        XCTAssertTrue(
            client.metOtherRead,
            "A second activities query must start while the first is in flight"
        )
    }
}
