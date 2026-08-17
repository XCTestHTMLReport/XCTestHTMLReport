//
//  ActivitiesDocumentCache.swift
//  XCTestHTMLReportCore
//
//  Extracted from ModernResultReader.swift, which the addition pushed past the
//  400-line file_length limit — the same split Summary+Reading.swift made.
//

import Foundation

/// Remembers each test's activities document for the life of one read.
///
/// `parseTestCase` asks once per repetition, passing the same identifier every
/// time, and the document that comes back already carries every repetition in
/// its `testRuns`. Uncached, a test that ran N times costs N identical
/// subprocesses whose answers are byte-for-byte the same — which at roughly
/// 115 ms per query is the most expensive redundancy in the reader. A miss is
/// stored even when the load failed, so a broken query is not retried (and not
/// re-reported) once per repetition.
///
/// Reference type because `ModernResultReader` is a struct whose `read()` is
/// non-mutating; a value-typed cache would be copied rather than shared.
final class ActivitiesDocumentCache {
    /// The lock is released while `load` runs, so a subprocess never blocks
    /// another test's lookup. Two threads racing the same identifier can both
    /// load, which costs a duplicate query and stores the same answer — the
    /// reads are serial today, and this stays correct when they are not.
    func document(
        for identifier: String,
        load: () -> TestActivities?
    ) -> TestActivities? {
        lock.lock()
        if let cached = documents[identifier] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let loaded = load()

        lock.lock()
        documents[identifier] = loaded
        lock.unlock()
        return loaded
    }

    // MARK: Private

    /// `TestActivities?` values, so a stored `nil` means "asked, and it failed"
    /// rather than "never asked".
    private var documents: [String: TestActivities?] = [:]
    private let lock = NSLock()
}
