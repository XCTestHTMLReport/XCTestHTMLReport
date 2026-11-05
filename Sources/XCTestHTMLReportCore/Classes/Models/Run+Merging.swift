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
    /// One summary per target and test plan configuration across
    /// `summariesPerRun`, so clones of one target render as one tree.
    ///
    /// Summaries pair by `(testName, configuration)`. A pair that occurs more
    /// than once within one run cannot be told apart, so those summaries are
    /// never paired; configurations from different runs that don't match stay
    /// separate too.
    static func coalescing(_ summariesPerRun: [[TestSummary]]) -> [TestSummary] {
        struct Identity: Hashable {
            let testName: String
            let configuration: String?
        }
        enum Key: Hashable {
            case matched(Identity)
            case ambiguous(run: Int, index: Int)
        }
        var keys: [Key] = []
        var groups: [Key: [TestSummary]] = [:]
        for (run, summaries) in summariesPerRun.enumerated() {
            let identities = summaries.map {
                Identity(testName: $0.testName, configuration: $0.configuration)
            }
            var counts: [Identity: Int] = [:]
            identities.forEach { counts[$0, default: 0] += 1 }
            for (index, summary) in summaries.enumerated() {
                let identity = identities[index]
                let key: Key = counts[identity] == 1
                    ? .matched(identity)
                    : .ambiguous(run: run, index: index)
                if groups[key] == nil {
                    keys.append(key)
                }
                groups[key, default: []].append(summary)
            }
        }
        // Same total order as `Run.init`: target name, then first appearance.
        return keys
            .compactMap { groups[$0].map(TestSummary.init(merging:)) }
            .enumerated()
            .sorted { ($0.element.testName, $0.offset) < ($1.element.testName, $1.offset) }
            .map(\.element)
    }

    init(merging summaries: [TestSummary]) {
        precondition(!summaries.isEmpty, "merging needs at least one summary")
        uuid = summaries[0].uuid
        testName = summaries[0].testName
        configuration = summaries[0].configuration
        tests = summaries.flatMap(\.tests)
    }
}
