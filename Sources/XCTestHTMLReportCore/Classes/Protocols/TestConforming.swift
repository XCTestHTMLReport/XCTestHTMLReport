//
//  TestConforming.swift
//
//
//  Created by Tyler Vick on 12/28/21.
//

import Foundation

protocol Test: HTML, ContainingAttachment {
    var uuid: String { get }
    var title: String { get }
    var identifier: String { get }
    var nodeKind: NodeKind { get }
    var status: Status { get }
    var duration: TimeInterval { get }
    /// How many times the run executed what this node stands for (#439, A3b).
    ///
    /// One row is not one execution: a repeated test carries an iteration per
    /// repetition, and a parameterized one carries a single row for several
    /// argument sets. `Run.numberOfExecutions` sums this over the leaves to
    /// state the second of Xcode's two numbers — 21 tests, 23 runs.
    var executionCount: Int { get }
}

extension Test {
    /// One, for every node that is exactly what it looks like. Only `TestCase`
    /// can hold more, and only `TestGroup` has children to sum.
    var executionCount: Int {
        1
    }
}
