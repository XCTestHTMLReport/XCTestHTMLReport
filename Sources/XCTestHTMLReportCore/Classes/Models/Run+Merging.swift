//
//  Run+Merging.swift
//  XCTestHTMLReport
//
//  `--merge-destinations` (#354): runs on equivalent destinations render as one.
//
//  Parallel testing clones and `xcresulttool merge` split one logical run
//  across identical devices; Xcode shows it as one tree.
//
//  Runs are merged after they are built, so attachments are already resolved
//  against their own bundles. Only the HTML is merged.
//

import Foundation

extension Run {
    /// Combines runs whose destinations share a model and OS version, keeping
    /// the order in which each destination first appears.
    ///
    /// A destination without a model name is never merged: an empty model says
    /// nothing about whether two devices are equivalent.
    static func mergingEquivalentDestinations(_ runs: [Run]) -> [Run] {
        var order: [String] = []
        var groups: [String: [Run]] = [:]
        for (index, run) in runs.enumerated() {
            let device = run.runDestination.targetDevice
            let key = device.model.isEmpty
                ? "unmergeable-\(index)"
                : "\(device.model)\u{0}\(device.osVersion)"
            if groups[key] == nil {
                order.append(key)
            }
            groups[key, default: []].append(run)
        }
        return order.compactMap { key in
            guard let group = groups[key] else {
                return nil
            }
            return group.count == 1 ? group[0] : Run(merging: group)
        }
    }

    /// One run holding every test summary and log of `runs`.
    ///
    /// The merged run has no log reference of its own, so it can never be
    /// mistaken for a log that failed to resolve; the originals still carry
    /// that signal into `Summary.validate()`.
    init(merging runs: [Run]) {
        precondition(!runs.isEmpty, "merging needs at least one run")
        file = runs[0].file
        runDestination = RunDestination(merging: runs.map(\.runDestination))
        testSummaries = TestSummary.coalescing(runs.map(\.testSummaries))
        logText = runs
            .filter { !$0.logText.isEmpty }
            .map { "==== \($0.runDestination.name) ====\n\($0.logText)" }
            .joined(separator: "\n")
        logContent = .none
        logReference = nil
    }
}

extension RunDestination {
    init(merging destinations: [RunDestination]) {
        precondition(!destinations.isEmpty, "merging needs at least one destination")
        let first = destinations[0]
        let names = Set(destinations.map(\.name))
        let identifiers = Set(destinations.map(\.targetDevice.identifier))
        name = names.count == 1
            ? first.name
            : "\(first.targetDevice.model) (\(identifiers.count) devices)"
        targetDevice = first.targetDevice
    }
}

extension TestSummary {
    /// One summary per target across `summariesPerRun`, so clones of one target
    /// render as one tree.
    ///
    /// A run already holds one summary per test plan configuration of a target,
    /// in `Run.init`'s order. The k-th summary of a target in one run pairs with
    /// the k-th of that target in the others, which keeps configurations apart.
    static func coalescing(_ summariesPerRun: [[TestSummary]]) -> [TestSummary] {
        struct Key: Hashable {
            let testName: String
            let occurrence: Int
        }
        var keys: [Key] = []
        var groups: [Key: [TestSummary]] = [:]
        for summaries in summariesPerRun {
            var occurrences: [String: Int] = [:]
            for summary in summaries {
                let occurrence = occurrences[summary.testName, default: 0]
                occurrences[summary.testName] = occurrence + 1
                let key = Key(testName: summary.testName, occurrence: occurrence)
                if groups[key] == nil {
                    keys.append(key)
                }
                groups[key, default: []].append(summary)
            }
        }
        return keys
            .sorted { ($0.testName, $0.occurrence) < ($1.testName, $1.occurrence) }
            .compactMap { groups[$0].map(TestSummary.init(merging:)) }
    }

    init(merging summaries: [TestSummary]) {
        precondition(!summaries.isEmpty, "merging needs at least one summary")
        uuid = summaries[0].uuid
        testName = summaries[0].testName
        tests = summaries.flatMap(\.tests)
    }
}
