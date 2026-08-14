//
//  SystemFailureCanaryTests.swift
//
//  A canary for the one literal `systemFailure` depends on (#478).
//
//  `ParsedGroup.systemFailureName` is a display name. Nothing structural
//  distinguishes Apple's crash bucket from a user's own suite on either
//  surface — modern renders it as `{"name": "System Failures", "nodeType":
//  "Test Suite"}`, legacy as an ordinary `ActionTestSummaryGroup` — so the name
//  is the only handle there is. That makes the rule fail *open*: rename the
//  group in some future Xcode and `systemFailure` stops firing, every healthy
//  fixture keeps passing, and nothing in the suite goes red. The report would
//  quietly go back to exiting 0 on a run that never finished, which is the bug
//  #478 was filed about.
//
//  So the literal is re-measured rather than assumed. `prepareTestResults.sh`
//  generates `CrashResults.xcresult` with the toolchain in front of it, by
//  setting `XCHR_TRAP_AT_LAUNCH` so the sample app traps in
//  `didFinishLaunchingWithOptions` and `SampleAppUnitTests` — which is hosted
//  in it — dies with it. That is the #478 failure reproduced, not simulated.
//  These tests then assert both readers still find the bucket by name in it.
//
//  The canary reaches the next Xcode before a release does: `toolchain-drift`
//  regenerates fixtures and runs this suite against the beta on its own leg
//  (#392), so a rename lands as a drift issue rather than as a silent
//  regression in the field.
//

import XCTest
@testable import XCTestHTMLReportCore

final class SystemFailureCanaryTests: XCTestCase {
    private static let fixture = "CrashResults"

    private func crashBundleURL() throws -> URL {
        try XCTUnwrap(
            Bundle.testBundle.url(forResource: Self.fixture, withExtension: "xcresult"),
            "\(Self.fixture).xcresult is missing — run ./prepareTestResults.sh"
        )
    }

    /// Every group name in the parsed tree, at any depth, in tree order.
    private func groupNames(in result: ParsedResult) -> [String] {
        func walk(_ group: ParsedGroup) -> [String] {
            [group.name] + group.children.flatMap { child -> [String] in
                guard case let .group(nested) = child else {
                    return []
                }
                return walk(nested)
            }
        }
        return result.runs.flatMap(\.testables).flatMap(\.groups).flatMap(walk)
    }

    /// Names every group the reader did produce, so a failure says what the
    /// bucket is called *now* instead of only that it is not called what it
    /// was. The second sentence is there because the other way this assertion
    /// fails is a trap that stopped firing, and the two are indistinguishable
    /// from the assertion alone.
    private func assertBucketIsPresent(
        in result: ParsedResult,
        reader: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let names = groupNames(in: result)
        XCTAssertTrue(
            names.contains(ParsedGroup.systemFailureName),
            """
            The \(reader) reader found no group named \
            "\(ParsedGroup.systemFailureName)" in a crash bundle this toolchain \
            just generated, so `systemFailure` is disarmed here. Groups found: \
            \(names). Either Apple renamed the bucket — update \
            ParsedGroup.systemFailureName and this fixture's expectations — or \
            XCHR_TRAP_AT_LAUNCH no longer trapping the sample app means \
            CrashResults.xcresult is not a crash bundle at all.
            """,
            file: file,
            line: line
        )
    }

    // MARK: The literal, per reader

    func testModernReaderStillNamesTheBucketSystemFailures() throws {
        let url = try crashBundleURL()
        let reader = ModernResultReader(
            client: XCResultToolClient(bundleURL: url),
            payloadStore: nil,
            faultCollector: FaultCollector()
        )

        try assertBucketIsPresent(in: XCTUnwrap(reader.read()), reader: "modern")
    }

    func testLegacyReaderStillNamesTheBucketSystemFailures() throws {
        // Skipped rather than failed once the toolchain drops the legacy
        // commands: at that point there is no legacy reader to disarm. The
        // modern half of the canary carries on alone, which is the direction
        // 4.0 is heading anyway.
        guard case .use(.legacy) = ResultBackend.legacy.resolve() else {
            throw XCTSkip("This toolchain no longer provides the legacy xcresulttool commands")
        }

        let file = try ResultFile(url: crashBundleURL(), faultCollector: FaultCollector())

        try assertBucketIsPresent(
            in: XCTUnwrap(LegacyResultReader(file: file).read()), reader: "legacy"
        )
    }

    // MARK: The fault the literal drives

    /// End to end, on every backend this toolchain can run: the bundle that
    /// used to render, print "Report successfully created" and exit 0 now
    /// records a fault.
    ///
    /// The detail differs by reader and that is not drift — modern names the
    /// crash row it decoded, legacy names the bucket, because legacy does not
    /// decode the row. Each is truthful about the document its reader saw, so
    /// this asserts the target and the count, not the wording.
    func testCrashBundleFaultsOnEveryAvailableBackend() throws {
        var backends: [ResultBackend] = [.modern]
        if case .use(.legacy) = ResultBackend.legacy.resolve() {
            backends.append(.legacy)
        }

        let url = try crashBundleURL()

        for backend in backends {
            let summary = Summary(
                resultPaths: [url.path],
                renderingMode: .linking,
                downsizeImagesEnabled: false,
                downsizeScaleFactor: 0.25,
                faultCollector: FaultCollector(),
                backend: backend
            )
            summary.validate()

            let details = summary.faults.filter { $0.kind == .systemFailure }.map(\.detail)

            XCTAssertEqual(
                details.count, 1,
                "\(backend.rawValue): expected exactly one system failure, got \(details)"
            )
            XCTAssertTrue(
                details.allSatisfy { $0.hasPrefix("SampleAppUnitTests: ") },
                """
                \(backend.rawValue): the fault must name the target that died \
                with the host app, got \(details)
                """
            )
        }
    }
}
