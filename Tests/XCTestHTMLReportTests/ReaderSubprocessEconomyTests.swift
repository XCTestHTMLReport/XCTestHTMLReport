//
//  ReaderSubprocessEconomyTests.swift
//
//  How many subprocesses a read costs. Reading a bundle is dominated by
//  `xcresulttool` spawns — roughly 115 ms per test case at the sizes measured
//  in `docs/reader-performance.md` — so a redundant spawn is not a tidiness
//  issue, it is the single most expensive mistake this reader can make.
//

import XCTest
@testable import XCTestHTMLReportCore

final class ReaderSubprocessEconomyTests: XCTestCase {
    /// A test that ran more than once must still cost one `activities` query.
    ///
    /// `parseTestCase` asks for activities once per repetition, passing the
    /// same identifier every time and keeping a different `testRuns` index from
    /// each answer. Uncached that is one subprocess per repetition returning
    /// byte-identical documents, so a run using `-retry-tests-on-failure` pays
    /// for its retries twice: once in the test run, once in the report.
    func testRepetitionsCostOneActivitiesQueryPerTest() throws {
        let (calls, _) = try readCountingActivityQueries("RetryResults")

        let repeated = "RetryTests/testJustFail()"
        XCTAssertEqual(
            calls.filter { $0 == repeated }.count, 1,
            "\(repeated) has two repetitions and must still be queried once"
        )
        XCTAssertEqual(
            calls.count, Set(calls).count,
            "Every test must be queried at most once; duplicates were \(duplicates(in: calls))"
        )
    }

    /// The saving must not come from skipping tests. A cache keyed too coarsely
    /// — on the bundle, say — would satisfy the assertion above by querying
    /// once in total and rendering everyone else's activities under one test.
    func testEveryTestIsStillQueried() throws {
        let (calls, testCases) = try readCountingActivityQueries("RetryResults")
        let identifiers = Set(testCases.map(\.identifier)).filter { !$0.isEmpty }

        XCTAssertEqual(
            Set(calls), identifiers,
            "Each test must be queried exactly once — no more, and no fewer"
        )
    }

    /// Repetitions must keep their own activities. This is the assertion that
    /// fails if a cache returns run 0's activities for every repetition.
    func testEachRepetitionKeepsItsOwnActivities() throws {
        let (_, testCases) = try readCountingActivityQueries("RetryResults")
        let repeated = try XCTUnwrap(
            testCases.first { $0.identifier == "RetryTests/testJustFail()" }
        )

        XCTAssertEqual(repeated.iterations.count, 2)
        let titles = repeated.iterations.map { iteration in
            iteration.activities.map(\.title)
        }
        XCTAssertNotEqual(
            titles[0], titles[1],
            "Both repetitions reported identical activities — the cache is "
                + "serving one run's answer for every repetition"
        )
    }

    // MARK: Private

    /// Wraps the real client so the tool still answers from the real bundle;
    /// only the questions asked are counted.
    private final class CountingClient: XCResultToolInvoking {
        init(wrapping wrapped: XCResultToolClient) {
            self.wrapped = wrapped
        }

        var bundleDescription: String {
            wrapped.bundleDescription
        }

        var activityQueries: [String] {
            lock.lock()
            defer { lock.unlock() }
            return queries
        }

        func run(_ arguments: [String]) throws -> Data {
            try wrapped.run(arguments)
        }

        func json<T: Decodable>(_ arguments: [String], as type: T.Type) throws -> T {
            if let index = arguments.firstIndex(of: "--test-id"),
               arguments.indices.contains(index + 1)
            {
                lock.lock()
                queries.append(arguments[index + 1])
                lock.unlock()
            }
            return try wrapped.json(arguments, as: type)
        }

        private let wrapped: XCResultToolClient
        private let lock = NSLock()
        private var queries: [String] = []
    }

    private func readCountingActivityQueries(
        _ resource: String
    ) throws -> (calls: [String], testCases: [ParsedTestCase]) {
        let url = try XCTUnwrap(
            Bundle.testBundle.url(forResource: resource, withExtension: "xcresult")
        )
        let client = CountingClient(wrapping: XCResultToolClient(bundleURL: url))
        let reader = ModernResultReader(
            client: client, payloadStore: nil, faultCollector: FaultCollector()
        )
        let result = try XCTUnwrap(reader.read())
        return (client.activityQueries, testCases(in: result))
    }

    private func testCases(in result: ParsedResult) -> [ParsedTestCase] {
        func walk(_ node: ParsedNode) -> [ParsedTestCase] {
            switch node {
            case let .group(group): return group.children.flatMap(walk)
            case let .testCase(testCase): return [testCase]
            }
        }
        return result.runs
            .flatMap(\.testables)
            .flatMap(\.groups)
            .flatMap { $0.children.flatMap(walk) }
    }

    private func duplicates(in calls: [String]) -> [String] {
        Set(calls).filter { id in calls.filter { $0 == id }.count > 1 }.sorted()
    }
}
