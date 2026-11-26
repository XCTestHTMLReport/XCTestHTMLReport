//
//  ConcurrentMap.swift
//  XCTestHTMLReportCore
//
//  Bounded concurrent `map` for the readers' per-test reads.
//

import Foundation

extension Array {
    /// `map`, with up to `width` transforms in flight at once, returning
    /// results in source order whatever order they finish in.
    ///
    /// Exists for the readers' per-test reads: each is an independent
    /// `xcresulttool` subprocess, and issued one at a time they leave a run
    /// waiting on process overhead (#162, `docs/reader-performance.md`).
    /// The default width matches the model-building queues in `Run.swift` and
    /// `Test.swift`, which is also the width 3.0.0 read at, back when those
    /// queues still wrapped the reads.
    ///
    /// The transform must be safe to call concurrently. The order of its
    /// side effects is not defined, so a caller whose side effects reach
    /// output must buffer them per element and replay them in source order.
    func concurrentMap<T>(
        width: Int = ProcessInfo.processInfo.processorCount * 2,
        _ transform: @escaping (Element) -> T
    ) -> [T] {
        guard count > 1, width > 1 else {
            return map(transform)
        }
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = width
        let lock = NSLock()
        var results = [T?](repeating: nil, count: count)
        for (index, element) in enumerated() {
            queue.addOperation {
                let result = transform(element)
                lock.lock()
                results[index] = result
                lock.unlock()
            }
        }
        queue.waitUntilAllOperationsAreFinished()
        // Every slot was filled by the operation that owned its index, so
        // this is a total unwrap; `compactMap` would hide a lost result.
        return results.map { $0! }
    }
}
