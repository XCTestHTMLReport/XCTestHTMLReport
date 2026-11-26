//
//  ModernResultReader+Tree.swift
//  XCTestHTMLReportCore
//
//  The walk from the tests document's node tree to the port's runs, groups
//  and rows. It never reads a test case itself: `read()` hands it the closure
//  that does, and walks it twice — once to learn which test case nodes to
//  read, once to place what was read — so the per-test reads can run
//  concurrently in between (#162).
//

import Foundation

extension ModernResultReader {
    static let bundleNodeTypes: Set<String> = [
        "UI test bundle", "Unit test bundle",
    ]

    /// The test tree as it ran on one destination.
    ///
    /// With a single destination — every fixture in this suite — this is the
    /// whole tree. With several, the tree must be filtered to the device,
    /// because `ParsedRun` is per-destination and duplicating the full tree
    /// under each run doubles every header total.
    ///
    /// `Device` is itself a `TestNodeType`, so a multi-destination document
    /// nests device nodes inside the tree. **Verify the shape against a real
    /// two-destination bundle before implementing this** — no fixture here
    /// produces one, and the single-destination case (no `Device` nodes,
    /// return the tree as-is) is the only shape confirmed on Xcode 26.2.
    func testables(
        on _: TestResultsDevice,
        from tests: TestResultsTests,
        testCase: (TestNode) -> ParsedTestCase
    ) -> [ParsedTestable] {
        (tests.testNodes ?? [])
            .flatMap { $0.children ?? [] }
            .filter { Self.bundleNodeTypes.contains($0.nodeType ?? "") }
            .map { bundle in
                ParsedTestable(
                    targetName: bundle.name ?? "",
                    groups: (bundle.children ?? []).map { parseGroup($0, testCase: testCase) }
                )
            }
    }

    /// One run per destination, matching legacy's one-run-per-ActionRecord.
    ///
    /// `testCase` turns each test case node into its row; `read()` walks this
    /// twice with different closures, once to learn which nodes to read and
    /// once to place what was read.
    func runs(
        on devices: [TestResultsDevice],
        from tests: TestResultsTests,
        testCase: (TestNode) -> ParsedTestCase
    ) -> [ParsedRun] {
        devices.map { device in
            ParsedRun(
                destination: ParsedDestination(
                    displayName: device.deviceName ?? "",
                    deviceIdentifier: device.deviceId ?? "",
                    modelName: device.modelName ?? "",
                    operatingSystemVersion: device.osVersion ?? ""
                ),
                // The action log has no reference id in the new format;
                // the payload store forwards this to `get log --type`.
                logReference: "action",
                testables: testables(on: device, from: tests, testCase: testCase)
            )
        }
    }

    func parseGroup(
        _ node: TestNode,
        testCase: (TestNode) -> ParsedTestCase
    ) -> ParsedGroup {
        let children: [ParsedNode] = (node.children ?? []).compactMap { child in
            switch child.nodeType {
            case "Test Case": return .testCase(testCase(child))
            case "Test Suite": return .group(parseGroup(child, testCase: testCase))
            default: return nil
            }
        }
        return ParsedGroup(
            name: node.name ?? "---group-name-not-found---",
            identifier: node.nodeIdentifier ?? node.name ?? "---group-identifier-not-found---",
            // `durationInSeconds` is null on every Test Suite, Test Plan and
            // *test bundle node in all three fixtures, so this is always 0 for
            // groups while legacy reports a real value. Not a bug to fix here —
            // the format does not carry it — but it is why `durations` is an
            // allow-list entry. Do not synthesise a sum of children: that would
            // be a fabricated number, and it would make the two backends agree
            // by inventing data rather than by sharing it.
            duration: node.durationInSeconds ?? 0,
            children: children
        )
    }
}
