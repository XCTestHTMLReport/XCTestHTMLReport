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
        // The same total order `Run.init` uses within one run, extended across
        // runs: target name first, then source position.
        testSummaries = runs
            .flatMap(\.testSummaries)
            .enumerated()
            .sorted { ($0.element.testName, $0.offset) < ($1.element.testName, $1.offset) }
            .map(\.element)
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
        name = names.count == 1
            ? first.name
            : "\(first.targetDevice.model) (\(names.count) devices)"
        targetDevice = first.targetDevice
    }
}
