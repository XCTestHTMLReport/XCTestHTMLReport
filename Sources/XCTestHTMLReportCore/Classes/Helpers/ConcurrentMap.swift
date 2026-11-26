//
//  ConcurrentMap.swift
//  XCTestHTMLReportCore
//
//  Bounded concurrent `map` for the readers' per-test reads.
//

import Foundation

/// `cpuCount * 2`, as 3.0.0 read and as the `Run`/`Test` queues still
/// render, capped at 20.
///
/// The cap exists because the uncapped width grows with the machine while
/// the speedup does not. The work is subprocess launch and `xcresulttool`
/// start-up, which stop scaling well before the core count does: 400 reads
/// took 3.06 / 1.95 / 1.61 / 1.67 / 1.46 / 1.50 s at widths 4 / 8 / 12 / 16 /
/// 20 / 32 on a 10-core M1 Max (#529 review), flat from about 12. A 32-core
/// machine would otherwise run 64 at once, which is the size of GCD's whole
/// worker pool and gains nothing over 20. 20 is the width the 10-core
/// measurements in `docs/reader-performance.md` were taken at, so the cap
/// changes nothing that was measured, and it leaves the pool two-thirds free
/// for everything else in the process.
let defaultConcurrentWidth = Swift.min(ProcessInfo.processInfo.processorCount * 2, 20)

extension Array {
    /// `map`, with up to `width` transforms in flight at once, returning
    /// results in source order whatever order they finish in.
    ///
    /// Exists for the readers' per-test reads: each is an independent
    /// `xcresulttool` subprocess, and issued one at a time they leave a run
    /// waiting on process overhead (#162, `docs/reader-performance.md`).
    ///
    /// The transform must be safe to call concurrently. The order of its
    /// side effects is not defined, so a caller whose side effects reach
    /// output must buffer them per element and replay them in source order.
    ///
    /// Do not call this from inside another `concurrentMap`, or from the
    /// `Run`/`Test` queues: every operation and every blocked waiter holds a
    /// thread from GCD's worker pool, which is capped at 64, and nesting
    /// multiplies the count.
    func concurrentMap<T>(
        width: Int = defaultConcurrentWidth,
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
