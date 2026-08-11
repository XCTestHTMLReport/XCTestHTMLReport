# xcresulttool Legacy Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the `xcresulttool --legacy` dependency with a reader
abstraction that has two backends — the existing XCResultKit path and a new one
reading Apple's current `xcresulttool` JSON — so `xchtmlreport` keeps working
after Apple removes the legacy commands.

**Architecture:** One port, two adapters. A backend-neutral `ParsedResult`
model sits between the readers and the renderer. `LegacyResultReader` wraps
XCResultKit; `ModernResultReader` drives `xcresulttool get test-results` and
`xcresulttool export attachments`. `Classes/Models/*` build from `ParsedResult`
and stop importing XCResultKit. HTML templates are untouched.

**Tech Stack:** Swift 5.5 tools version, macOS 10.15 floor, SwiftPM, XCTest,
SwiftSoup (test-only), XCResultKit (legacy backend only, removed in a later
issue), `xcrun xcresulttool`.

**Spec:** `docs/superpowers/specs/2026-08-10-xcresulttool-legacy-migration-design.md`

## Global Constraints

- Swift tools version **5.5**; platform floor **macOS 10.15**. Do not raise either.
- `Sources/XCTestHTMLReportCore/Classes/HTMLTemplates.swift` is generated and
  excluded from SwiftFormat and SwiftLint. **Never edit it.** No task in this
  plan changes report markup.
- SwiftFormat config wraps at 100 columns, `--wraparguments before-first`,
  `--wrapparameters before-first`, `--acronyms ID,URL,UUID`,
  `--importgrouping alpha`, `--marktypes always`. Run `swiftformat .` before
  every commit.
- SwiftLint `line_length` errors above 200 columns.
- Required CI checks are `shell`, `swift`, `test`. All three must be green.
- A pre-commit hook runs via `core.hooksPath` (`.githooks/`). Do not bypass it.
- Fixtures come from `./prepareTestResults.sh` and are **regenerated on every
  CI run**, so durations, timestamps, device names, and UUIDs all vary between
  runs. **Checked-in golden HTML files are impossible.** Every comparison must
  be between two renders produced within the same run.
- `FaultCollector` faults cause exit code 3 and the test harness asserts on the
  string `"Report is degraded"`. A field the active backend structurally cannot
  provide is **never** a fault.
- Do not make performance claims. If one is unavoidable, it requires a
  same-runner interleaved A/B, never a cross-run CI wall-clock comparison.
- Verification steps in this plan pipe into `tail` to trim output, which makes
  the pipeline report `tail`'s exit status rather than the build's. Run
  `set -o pipefail` in your shell before working through the plan, or read the
  printed result rather than trusting `$?`. A silent pass from a failed
  `swift build` is worse than noisy output.

---

## File Structure

**Created:**

| Path | Responsibility |
| --- | --- |
| `Classes/ResultReading/ParsedResult.swift` | Backend-neutral model. Plain value types, no I/O. |
| `Classes/ResultReading/ResultReader.swift` | `ResultReader` protocol + `PayloadProviding` protocol. |
| `Classes/ResultReading/ResultBackend.swift` | Backend enum, toolchain capability detection, override plumbing. |
| `Classes/ResultReading/Legacy/LegacyResultReader.swift` | XCResultKit → `ParsedResult`. The only file importing XCResultKit after Task 5. |
| `Classes/ResultReading/Modern/XCResultToolClient.swift` | Subprocess execution, schema-version pinning, JSON decode. |
| `Classes/ResultReading/Modern/TestResultsSchema.swift` | `Codable` structs mirroring the new format. |
| `Classes/ResultReading/Modern/ModernResultReader.swift` | New format → `ParsedResult`. |
| `Classes/ResultReading/Modern/ModernPayloadStore.swift` | `export attachments` + manifest join + payload lookup. |
| `Tests/.../ReportNormalizer.swift` | UUID normalization used by every comparison test. |
| `Tests/.../ReproducibilityTests.swift` | Pins that normalized renders are stable. |
| `Tests/.../DifferentialTests.swift` | Legacy vs modern, per fixture. |
| `Tests/.../Resources/differential-allowlist.json` | Declared, reviewable known-loss list. |

**Modified:** every file under `Classes/Models/` plus
`Classes/Protocols/EmittableOutput.swift` (drop XCResultKit imports),
`Sources/XCTestHTMLReport/XCTestHtmlReport.swift` (new flag, `--json`),
`.github/workflows/test.yml` (forced-modern leg), `README.md`.

---

## Task 1: UUID normalization and a reproducibility pin

The refactor in Task 5 must be provably behavior-preserving, and the
differential in Task 12 must diff two renders. Both need one normalizer. Build
it first, and prove it works by pinning something true today.

**Files:**
- Create: `Tests/XCTestHTMLReportTests/ReportNormalizer.swift`
- Create: `Tests/XCTestHTMLReportTests/ReproducibilityTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `func normalizeReport(_ html: String) -> String` — replaces every
  RFC-4122-shaped uppercase UUID with the literal `UUID`. Used by Tasks 5 and 12.

- [ ] **Step 1: Write the failing test**

`Tests/XCTestHTMLReportTests/ReproducibilityTests.swift`:

```swift
//
//  ReproducibilityTests.swift
//
//  Pins that two renders of one bundle differ only in synthesized UUIDs.
//  Every comparison test in this suite depends on that being true.
//

import XCTest
@testable import XCTestHTMLReportCore

final class ReproducibilityTests: XCTestCase {
    private func render(_ resource: String) throws -> String {
        let url = try XCTUnwrap(
            Bundle.testBundle.url(forResource: resource, withExtension: "xcresult")
        )
        return Summary(
            resultPaths: [url.path],
            renderingMode: .linking,
            downsizeImagesEnabled: false,
            downsizeScaleFactor: 0.5
        ).generatedHtmlReport()
    }

    func testRawRendersDifferOnlyByUUIDs() throws {
        let first = try render("SanityResults")
        let second = try render("SanityResults")

        // Guards against the normalizer being vacuous: if the raw renders were
        // already identical, the normalized comparison below would prove nothing.
        XCTAssertNotEqual(
            first, second,
            "Expected synthesized UUIDs to differ between renders"
        )
        XCTAssertEqual(normalizeReport(first), normalizeReport(second))
    }

    func testNormalizerReplacesUUIDsAndNothingElse() {
        let input = "id=A3B2A5BD-6FC1-4D77-8554-3A2BDBF6BE5F name=FirstSuite/testTwo()"
        XCTAssertEqual(normalizeReport(input), "id=UUID name=FirstSuite/testTwo()")
    }
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
swift test --filter ReproducibilityTests
```

Expected: FAIL — `cannot find 'normalizeReport' in scope`.

- [ ] **Step 3: Implement the normalizer**

`Tests/XCTestHTMLReportTests/ReportNormalizer.swift`:

```swift
//
//  ReportNormalizer.swift
//
//  The report embeds freshly generated UUIDs on every render
//  (`Activity.uuid`, `TestCase.uuid`, `TestGroup.uuid`, `TestSummary.uuid`,
//  `TargetDevice.uniqueIdentifier`), so two renders of one bundle are never
//  byte-identical. Comparisons normalize them away first; without this step a
//  diff reports a difference on every run and proves nothing.
//

import Foundation

private let uuidPattern = try! NSRegularExpression(
    pattern: "[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}"
)

/// Replaces every uppercase RFC-4122 UUID with the literal `UUID`.
func normalizeReport(_ html: String) -> String {
    uuidPattern.stringByReplacingMatches(
        in: html,
        range: NSRange(html.startIndex..., in: html),
        withTemplate: "UUID"
    )
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
swift test --filter ReproducibilityTests
```

Expected: PASS, 2 tests.

- [ ] **Step 5: Commit**

```bash
swiftformat . && git add Tests/XCTestHTMLReportTests/ReportNormalizer.swift \
  Tests/XCTestHTMLReportTests/ReproducibilityTests.swift
git commit -m "test: pin that renders differ only by synthesized UUIDs"
```

---

## Task 2: Capture the pre-refactor baseline

Fixtures are regenerated per run, so no golden can be checked in. The Task 5
refactor is instead guarded by capturing a normalized render **now** and
diffing after, within one fixture generation.

**Files:**
- Create: `Tests/XCTestHTMLReportTests/BaselineCaptureTests.swift`

**Interfaces:**
- Consumes: `normalizeReport(_:)` from Task 1.
- Produces: a test that writes normalized renders when `XCHR_BASELINE_DIR` is
  set, and skips otherwise. Used manually in Task 5, then kept for any future
  rendering change.

- [ ] **Step 1: Write the capture test**

```swift
//
//  BaselineCaptureTests.swift
//
//  Writes normalized renders of every fixture to $XCHR_BASELINE_DIR.
//  Fixtures are regenerated on each `prepareTestResults.sh` run, so a golden
//  file cannot be checked in; capture before a refactor and again after,
//  against one fixture generation, then diff the two directories.
//

import XCTest
@testable import XCTestHTMLReportCore

final class BaselineCaptureTests: XCTestCase {
    func testCaptureNormalizedRenders() throws {
        guard let dir = ProcessInfo.processInfo.environment["XCHR_BASELINE_DIR"] else {
            throw XCTSkip("Set XCHR_BASELINE_DIR to capture baseline renders")
        }
        try FileManager.default.createDirectory(
            atPath: dir, withIntermediateDirectories: true
        )

        let resources = ["TestResults", "SanityResults", "RetryResults"]
        for resource in resources {
            // Deliberately not `continue`: a skipped fixture would produce a
            // partial baseline, and Task 5's `diff -r` reports two partial
            // directories as identical. Fail here instead.
            let url = try XCTUnwrap(
                Bundle.testBundle.url(forResource: resource, withExtension: "xcresult"),
                "Fixture \(resource).xcresult is missing — run ./prepareTestResults.sh"
            )
            let html = Summary(
                resultPaths: [url.path],
                renderingMode: .linking,
                downsizeImagesEnabled: false,
                downsizeScaleFactor: 0.5
            ).generatedHtmlReport()
            let path = "\(dir)/\(resource).html"
            try normalizeReport(html).write(
                toFile: path, atomically: true, encoding: .utf8
            )
            let written = try XCTUnwrap(
                FileManager.default.contents(atPath: path)
            )
            XCTAssertFalse(written.isEmpty, "\(resource) captured an empty baseline")
        }

        let captured = try FileManager.default
            .contentsOfDirectory(atPath: dir)
            .filter { $0.hasSuffix(".html") }
        XCTAssertEqual(
            Set(captured), Set(resources.map { "\($0).html" }),
            "Baseline must contain exactly one file per fixture"
        )
    }
}
```

- [ ] **Step 2: Run it and confirm it skips by default**

```bash
swift test --filter BaselineCaptureTests
```

Expected: PASS with one skipped test.

- [ ] **Step 3: Capture the actual baseline**

```bash
XCHR_BASELINE_DIR=/tmp/xchr-baseline swift test --filter BaselineCaptureTests
ls -la /tmp/xchr-baseline
```

Expected: three non-empty `.html` files. **Do not regenerate fixtures again
until Task 5 is verified** — a new fixture generation invalidates this baseline.

- [ ] **Step 4: Commit**

```bash
swiftformat . && git add Tests/XCTestHTMLReportTests/BaselineCaptureTests.swift
git commit -m "test: add opt-in baseline render capture for refactor guarding"
```

---

## Task 3: The `ParsedResult` model

Pure value types, no I/O, no XCResultKit. Lossy fields are optional; the
renderer already treats them that way.

**Files:**
- Create: `Sources/XCTestHTMLReportCore/Classes/ResultReading/ParsedResult.swift`
- Create: `Sources/XCTestHTMLReportCore/Classes/ResultReading/ResultReader.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: the types below. Task 4 populates them from XCResultKit; Tasks 8–10
  populate them from `xcresulttool`; Task 5 renders from them.

- [ ] **Step 1: Write the model**

```swift
//
//  ParsedResult.swift
//  XCTestHTMLReportCore
//
//  Backend-neutral representation of one .xcresult bundle. Both the legacy
//  (XCResultKit) and modern (xcresulttool) readers produce this, and the
//  renderer consumes only this.
//
//  Optional fields are ones at least one backend cannot provide. The modern
//  format has no activity type, no activity finish time, no user-supplied
//  attachment name, no attachment UTI, and no structured failure location.
//  Their absence is a format limitation, never a Fault.
//

import Foundation

public struct ParsedResult {
    public let runs: [ParsedRun]
}

public struct ParsedRun {
    public let destination: ParsedDestination
    public let logReference: String?
    public let testables: [ParsedTestable]
}

public struct ParsedDestination {
    public let displayName: String
    public let deviceIdentifier: String
    public let modelName: String
    public let operatingSystemVersion: String
}

/// One test target within a run — `ActionTestableSummary` on legacy, a
/// `UI test bundle` / `Unit test bundle` node on modern.
public struct ParsedTestable {
    public let targetName: String
    public let groups: [ParsedGroup]
}

public indirect enum ParsedNode {
    case group(ParsedGroup)
    case testCase(ParsedTestCase)
}

public struct ParsedGroup {
    public let name: String
    public let identifier: String
    public let duration: TimeInterval
    public let children: [ParsedNode]
}

/// A test method. Carries one entry per repetition; a non-repeated test has
/// exactly one.
public struct ParsedTestCase {
    public let name: String
    public let identifier: String
    public let iterations: [ParsedIteration]
}

public struct ParsedIteration {
    /// 1-based. `nil` when the backend reports no repetition information.
    public let iterationNumber: Int?
    public let statusRawValue: String
    public let duration: TimeInterval
    public let activities: [ParsedActivity]
}

public struct ParsedActivity {
    public let title: String
    /// Legacy `activityType` raw value. `nil` on the modern backend.
    public let activityType: String?
    /// True when the backend marks this activity as a failure. Legacy derives
    /// it from `activityType`; modern reads `isAssociatedWithFailure`.
    public let isFailure: Bool
    public let start: Date?
    /// `nil` on the modern backend, which reports only a start time.
    public let finish: Date?
    public let attachments: [ParsedAttachment]
    public let subActivities: [ParsedActivity]
}

public struct ParsedAttachment {
    /// User-supplied name. `nil` on the modern backend.
    public let name: String?
    public let filename: String?
    /// Uniform type identifier. `nil` on the modern backend, which supplies
    /// `filenameExtension` instead.
    public let uniformTypeIdentifier: String?
    public let filenameExtension: String?
    /// Opaque handle the backend's payload provider resolves to bytes.
    public let payloadReference: String?
}
```

- [ ] **Step 2: Write the reader protocols**

```swift
//
//  ResultReader.swift
//  XCTestHTMLReportCore
//

import Foundation

/// Reads one result bundle into the backend-neutral model.
protocol ResultReader {
    func read() -> ParsedResult?
}

/// Resolves the opaque payload references in `ParsedAttachment` to bytes, and
/// the run log reference to text.
protocol PayloadProviding {
    /// Exports the payload to a file inside the bundle directory and returns a
    /// bundle-relative URL, or `nil` on failure.
    func exportPayload(reference: String, fileName: String?) -> URL?
    func exportPayloadData(reference: String) -> Data?
    func exportLogs(reference: String) -> URL?
    func exportLogsData(reference: String) -> Data?
}
```

- [ ] **Step 3: Verify it compiles**

```bash
swift build 2>&1 | tail -5
```

Expected: no errors. Nothing consumes these types yet.

- [ ] **Step 4: Commit**

```bash
swiftformat . && git add Sources/XCTestHTMLReportCore/Classes/ResultReading/
git commit -m "feat: add backend-neutral ParsedResult model and reader protocols"
```

---

## Task 4: `LegacyResultReader`

Translate XCResultKit's graph into `ParsedResult`, preserving today's semantics
exactly — including the repetition dedup that produces `.mixed`.

**Files:**
- Create: `Sources/XCTestHTMLReportCore/Classes/ResultReading/Legacy/LegacyResultReader.swift`
- Create: `Tests/XCTestHTMLReportTests/LegacyResultReaderTests.swift`

**Interfaces:**
- Consumes: `ParsedResult` types (Task 3); `ResultFile` (existing).
- Produces: `LegacyResultReader(file: ResultFile)` conforming to `ResultReader`.

**Critical semantics to preserve.** Legacy emits repetitions as **duplicate
sibling `ActionTestMetadata` entries sharing one identifier**, distinguished by
`repetitionPolicySummary.iteration` (which lives in the summary, so it costs a
fetch). Today `TestGroup.init` merges them via a `Set<TestCase>`. That merge
moves into this reader: group siblings by identifier, sort iterations by
`iteration`, and emit one `ParsedTestCase`.

- [ ] **Step 1: Write the failing test**

```swift
//
//  LegacyResultReaderTests.swift
//

import XCTest
@testable import XCTestHTMLReportCore

final class LegacyResultReaderTests: XCTestCase {
    private func read(_ resource: String) throws -> ParsedResult {
        let url = try XCTUnwrap(
            Bundle.testBundle.url(forResource: resource, withExtension: "xcresult")
        )
        let file = ResultFile(url: url, faultCollector: FaultCollector())
        return try XCTUnwrap(LegacyResultReader(file: file).read())
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

    func testRepetitionsMergeIntoOneTestCase() throws {
        let cases = testCases(in: try read("RetryResults"))

        // Legacy emits testRetryOnFailure twice as sibling metadata entries;
        // the reader must merge them into one case with two iterations.
        let retried = try XCTUnwrap(
            cases.first { $0.identifier == "RetryTests/testRetryOnFailure()" }
        )
        XCTAssertEqual(retried.iterations.count, 2)
        XCTAssertEqual(retried.iterations.map(\.iterationNumber), [1, 2])
        XCTAssertEqual(
            retried.iterations.map(\.statusRawValue), ["Failure", "Success"]
        )

        // And a non-repeated test still has exactly one iteration.
        let passed = try XCTUnwrap(
            cases.first { $0.identifier == "RetryTests/testJustPass()" }
        )
        XCTAssertEqual(passed.iterations.count, 1)
    }

    func testAttachmentFieldsSurviveTranslation() throws {
        let cases = testCases(in: try read("TestResults"))
        let special = try XCTUnwrap(
            cases.first { $0.identifier == "FirstSuite/testWithSpecialChars()" }
        )

        func allAttachments(_ activities: [ParsedActivity]) -> [ParsedAttachment] {
            activities.flatMap { $0.attachments + allAttachments($0.subActivities) }
        }
        let attachments = allAttachments(special.iterations[0].activities)

        // The user-supplied name is distinct from the generated filename on
        // legacy. Losing that distinction is the modern backend's behaviour,
        // and must not leak into this one.
        let named = try XCTUnwrap(
            attachments.first { $0.name?.hasPrefix("FileName with") == true }
        )
        XCTAssertEqual(named.uniformTypeIdentifier, "public.plain-text")
        XCTAssertNotEqual(named.name, named.filename)
        XCTAssertEqual(named.filename?.hasSuffix(".txt"), true)
    }

    func testDestinationIsPopulated() throws {
        let run = try XCTUnwrap(try read("SanityResults").runs.first)
        XCTAssertFalse(run.destination.displayName.isEmpty)
        XCTAssertFalse(run.destination.modelName.isEmpty)
        XCTAssertFalse(run.destination.operatingSystemVersion.isEmpty)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
swift test --filter LegacyResultReaderTests
```

Expected: FAIL — `cannot find 'LegacyResultReader' in scope`.

- [ ] **Step 3: Implement the reader**

```swift
//
//  LegacyResultReader.swift
//  XCTestHTMLReportCore
//
//  Translates XCResultKit's object graph into ParsedResult. This is the only
//  file in the target that imports XCResultKit; it is deleted wholesale once
//  Apple removes the legacy commands.
//

import Foundation
import XCResultKit

struct LegacyResultReader: ResultReader {
    let file: ResultFile

    func read() -> ParsedResult? {
        guard let record = file.getInvocationRecord() else {
            return nil
        }
        return ParsedResult(runs: record.actions.compactMap(parseRun))
    }

    private func parseRun(_ action: ActionRecord) -> ParsedRun? {
        guard
            let testsRef = action.actionResult.testsRef,
            let plan = file.getTestPlanRunSummaries(id: testsRef.id)
        else {
            Logger.warning("Can't find test reference for action \(action.title ?? "")")
            return nil
        }
        let device = action.runDestination.targetDeviceRecord
        return ParsedRun(
            destination: ParsedDestination(
                displayName: action.runDestination.displayName,
                deviceIdentifier: device.identifier,
                modelName: device.modelName,
                operatingSystemVersion: device.operatingSystemVersion
            ),
            logReference: action.actionResult.logRef?.id,
            testables: plan.summaries.flatMap(\.testableSummaries).map { summary in
                ParsedTestable(
                    targetName: summary.targetName ?? "",
                    groups: summary.tests.map(parseGroup)
                )
            }
        )
    }

    private func parseGroup(_ group: ActionTestSummaryGroup) -> ParsedGroup {
        // Legacy lists each repetition as its own sibling metadata entry under
        // one identifier. Merge them here so the renderer sees one test case
        // with N iterations, which is what TestGroup.init used to do inline.
        var order: [String] = []
        var buckets: [String: [ActionTestMetadata]] = [:]
        for metadata in group.subtests {
            let identifier = metadata.identifier ?? ""
            if buckets[identifier] == nil {
                order.append(identifier)
            }
            buckets[identifier, default: []].append(metadata)
        }

        let cases: [ParsedNode] = order.map { identifier in
            let entries = buckets[identifier] ?? []
            let iterations = entries
                .map(parseIteration)
                .sorted { ($0.iterationNumber ?? 0) < ($1.iterationNumber ?? 0) }
            return .testCase(ParsedTestCase(
                name: entries.first?.name ?? "",
                identifier: identifier,
                iterations: iterations
            ))
        }

        return ParsedGroup(
            name: group.name ?? "---group-name-not-found---",
            identifier: group.identifier ?? "---group-identifier-not-found---",
            duration: group.duration,
            children: cases + group.subtestGroups.map { .group(parseGroup($0)) }
        )
    }

    private func parseIteration(_ metadata: ActionTestMetadata) -> ParsedIteration {
        guard
            let id = metadata.summaryRef?.id,
            let summary = file.getActionTestSummary(id: id)
        else {
            return ParsedIteration(
                iterationNumber: nil,
                statusRawValue: metadata.testStatus,
                duration: metadata.duration ?? 0,
                activities: []
            )
        }

        let activities = summary.activitySummaries.map(parseActivity)

        // As of xcresulttool 3.39 assertion failures are no longer nested in
        // ActionTestActivitySummary, so failure summaries are interleaved by
        // finish time. When failing sub-activities are already present we are
        // on an older tool and must not add them twice.
        let combined: [ParsedActivity]
        if activities.contains(where: hasFailure) {
            combined = activities
        } else {
            let failures = summary.failureSummaries.map(parseFailure)
            combined = (activities + failures).sorted {
                ($0.finish ?? .distantPast) < ($1.finish ?? .distantPast)
            }
        }

        return ParsedIteration(
            iterationNumber: summary.repetitionPolicySummary?.iteration,
            statusRawValue: metadata.testStatus,
            duration: metadata.duration ?? 0,
            activities: combined
        )
    }

    private func hasFailure(_ activity: ParsedActivity) -> Bool {
        activity.isFailure || activity.subActivities.contains(where: hasFailure)
    }

    private func parseActivity(_ summary: ActionTestActivitySummary) -> ParsedActivity {
        ParsedActivity(
            title: summary.title,
            activityType: summary.activityType,
            isFailure: summary.activityType
                == "com.apple.dt.xctest.activity-type.testAssertionFailure",
            start: summary.start,
            finish: summary.finish,
            attachments: summary.attachments.map(parseAttachment),
            subActivities: summary.subactivities.map(parseActivity)
        )
    }

    private func parseFailure(_ summary: ActionTestFailureSummary) -> ParsedActivity {
        let issueType = summary.issueType ?? "Assertion Failure"
        let message = summary.message ?? "[message not provided]"
        let file = summary.fileName?.lastPathComponent() ?? ""
        return ParsedActivity(
            title: "\(issueType) at \(file):\(summary.lineNumber):\(message)",
            activityType: "com.apple.dt.xctest.activity-type.testAssertionFailure",
            isFailure: true,
            start: summary.timestamp,
            finish: summary.timestamp,
            attachments: summary.attachments.map(parseAttachment),
            subActivities: []
        )
    }

    private func parseAttachment(_ attachment: ActionTestAttachment) -> ParsedAttachment {
        ParsedAttachment(
            name: attachment.name,
            filename: attachment.filename,
            uniformTypeIdentifier: attachment.uniformTypeIdentifier,
            filenameExtension: nil,
            payloadReference: attachment.payloadRef?.id
        )
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
swift test --filter LegacyResultReaderTests
```

Expected: PASS, 3 tests. If `testRepetitionsMergeIntoOneTestCase` fails on
iteration ordering, check that `repetitionPolicySummary.iteration` is being
read from the *summary*, not the metadata.

- [ ] **Step 5: Commit**

```bash
swiftformat . && git add Sources/XCTestHTMLReportCore/Classes/ResultReading/Legacy/ \
  Tests/XCTestHTMLReportTests/LegacyResultReaderTests.swift
git commit -m "feat: add LegacyResultReader translating XCResultKit to ParsedResult"
```

---

## Task 5: Move the renderer onto `ParsedResult`

The largest task and the one with no behavior change. Guarded by the Task 2
baseline.

**Files:**
- Modify: `Classes/Models/Summary.swift`, `Run.swift`, `TestSummary.swift`,
  `Test.swift`, `Iteration.swift`, `Activity.swift`, `Attachment.swift`,
  `RunDestination.swift`, `TargetDevice.swift`, `ResultFile.swift`
- Modify: `Classes/Protocols/EmittableOutput.swift`

**Interfaces:**
- Consumes: everything from Tasks 3 and 4.
- Produces: model initializers taking `Parsed*` types instead of XCResultKit
  types. `ResultFile` conforms to `PayloadProviding`.

- [ ] **Step 1: Rewrite each model initializer**

Mechanical, one file at a time. The substitutions:

| Model | Was | Becomes |
| --- | --- | --- |
| `Run` | `init?(action: ActionRecord, ...)` | `init?(run: ParsedRun, ...)` |
| `TestSummary` | `init(summary: ActionTestableSummary, ...)` | `init(testable: ParsedTestable, ...)` |
| `TestGroup` | `init(group: ActionTestSummaryGroup, ...)` | `init(group: ParsedGroup, ...)` |
| `TestCase` | `init(metadata: ActionTestMetadata, ...)` | `init(testCase: ParsedTestCase, ...)` |
| `Iteration` | `init(metadata: ActionTestMetadata, ...)` | `init(iteration: ParsedIteration, ...)` |
| `Activity` | two inits (`summary:`, `failureSummary:`) | one `init(activity: ParsedActivity, ...)` |
| `Attachment` | `init(attachment: ActionTestAttachment, ...)` | `init(attachment: ParsedAttachment, ...)` |
| `RunDestination` | `init(record: ActionRunDestinationRecord)` | `init(destination: ParsedDestination)` |
| `TargetDevice` | `init(record: ActionDeviceRecord)` | `init(destination: ParsedDestination)` |

Four behaviors move out of the models and must **not** be reimplemented there:

1. `TestGroup.init`'s `Set<TestCase>` repetition merge — now in the reader.
   `TestGroup` builds `TestCase`s directly from `ParsedGroup.children`.
2. `TestCase: Hashable` existed only for that merge. Delete the conformance.
3. `Iteration.init`'s failure-summary interleaving — now in the reader.
   `Iteration` maps `ParsedIteration.activities` one-to-one.
4. `Activity`'s two initializers collapse to one; `ParsedActivity.title` is
   already the formatted failure title for failure-derived activities.

`Activity.uuid` was `ActionTestActivitySummary.uuid`; it is now
`UUID().uuidString`, matching how the other models already synthesize theirs
and how the HTML uses it (an element id only). `Activity.type` becomes
`ParsedActivity.activityType.flatMap(ActivityType.init(rawValue:))`.

`Iteration.repetitionPolicy` was `ActionTestRepetitionPolicySummary?`; it
becomes `Int?` from `ParsedIteration.iterationNumber`, and the HTML
`"Iteration \(repetitionPolicy?.iteration ?? 0)"` becomes
`"Iteration \(iterationNumber ?? 0)"`.

- [ ] **Step 2: Rewire `Summary.init` through the reader**

```swift
for resultPath in resultPaths {
    Logger.step("Parsing \(resultPath)")
    let url = URL(fileURLWithPath: resultPath)
    let resultFile = ResultFile(url: url, faultCollector: faultCollector)
    resultFiles.append(resultFile)
    guard let parsed = LegacyResultReader(file: resultFile).read() else {
        Logger.warning("Can't find invocation record for : \(resultPath)")
        faultCollector.record(.missingInvocationRecord, resultPath)
        continue
    }
    runs.append(contentsOf: parsed.runs.compactMap {
        Run(
            run: $0,
            file: resultFile,
            renderingMode: renderingMode,
            downsizeImagesEnabled: downsizeImagesEnabled,
            downsizeScaleFactor: downsizeScaleFactor
        )
    })
}
```

- [ ] **Step 3: Make `ResultFile` a `PayloadProviding` conformer**

Rename its methods to the protocol's names (`exportPayload(reference:fileName:)`,
`exportPayloadData(reference:)`, `exportLogs(reference:)`,
`exportLogsData(reference:)`). Delete `getInvocationRecord()`,
`getTestPlanRunSummaries(id:)`, `getActionTestSummary(id:)` — the reader owns
those now — and delete **`getCodeCoverage()`**, which is defined and never
called anywhere in the target. Keep `exportJson()` until Task 15.

Keep the per-id `payloadLockTable` and both `NSLock` comment blocks verbatim.
They document a real race in XCResultKit's shared-temp-path export, and the
legacy backend still hits it.

- [ ] **Step 4: Build and run the full suite**

```bash
swift build 2>&1 | tail -20 && swift test 2>&1 | tail -15
```

Expected: builds clean, and **every test passes with zero failures**. The
count is above the original 23 by this point — Tasks 1, 2, and 4 each added
tests — so check for `0 failures`, not for a specific total. `Models/*` and
`Protocols/EmittableOutput.swift` no longer import XCResultKit:

```bash
grep -rln "import XCResultKit" Sources/ | grep -v ResultReading/Legacy
```

Expected: no output.

- [ ] **Step 5: Verify against the Task 2 baseline**

```bash
XCHR_BASELINE_DIR=/tmp/xchr-after swift test --filter BaselineCaptureTests
diff -r /tmp/xchr-baseline /tmp/xchr-after && echo "IDENTICAL — refactor is behaviour-preserving"
```

Expected: `IDENTICAL`. **Any difference is a regression in this task, not an
acceptable change.** Investigate before proceeding; the whole point of Task 2
was to make this checkable. If fixtures were regenerated since Task 2, the
baseline is void — redo Task 2 step 3 from the pre-refactor commit.

- [ ] **Step 6: Commit**

```bash
swiftformat . && git add -A
git commit -m "refactor: render from ParsedResult instead of XCResultKit types

Verified behaviour-preserving: normalized renders of all three fixtures are
byte-identical before and after, against one fixture generation."
```

---

## Task 6: `XCResultToolClient`

Subprocess plumbing for the modern backend, with the schema version pinned.

**Files:**
- Create: `Sources/XCTestHTMLReportCore/Classes/ResultReading/Modern/XCResultToolClient.swift`
- Create: `Tests/XCTestHTMLReportTests/XCResultToolClientTests.swift`

**Interfaces:**
- Produces: `XCResultToolClient(bundleURL: URL)` with
  `func json<T: Decodable>(_ arguments: [String], as: T.Type) throws -> T`,
  `func run(_ arguments: [String]) throws -> Data`, and
  `static var legacyCommandsAvailable: Bool`.

- [ ] **Step 1: Write the failing test**

```swift
//
//  XCResultToolClientTests.swift
//

import XCTest
@testable import XCTestHTMLReportCore

final class XCResultToolClientTests: XCTestCase {
    private struct SummaryProbe: Decodable {
        let totalTestCount: Int
        let title: String
    }

    func testDecodesSummaryDocument() throws {
        let url = try XCTUnwrap(
            Bundle.testBundle.url(forResource: "SanityResults", withExtension: "xcresult")
        )
        let client = XCResultToolClient(bundleURL: url)
        let probe = try client.json(
            ["get", "test-results", "summary"], as: SummaryProbe.self
        )
        XCTAssertEqual(probe.totalTestCount, 1)
        XCTAssertFalse(probe.title.isEmpty)
    }

    func testUnknownSubcommandThrows() throws {
        let url = try XCTUnwrap(
            Bundle.testBundle.url(forResource: "SanityResults", withExtension: "xcresult")
        )
        let client = XCResultToolClient(bundleURL: url)
        XCTAssertThrowsError(
            try client.json(["get", "test-results", "nope"], as: SummaryProbe.self)
        )
    }

    func testLegacyAvailabilityIsDetectable() {
        // Not asserting a value: it is true on today's toolchains and false
        // once Apple removes the legacy commands. Asserting either would make
        // this test a time bomb. Assert only that detection runs.
        _ = XCResultToolClient.legacyCommandsAvailable
    }
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
swift test --filter XCResultToolClientTests
```

Expected: FAIL — `cannot find 'XCResultToolClient' in scope`.

- [ ] **Step 3: Implement the client**

```swift
//
//  XCResultToolClient.swift
//  XCTestHTMLReportCore
//
//  Runs `xcrun xcresulttool` and decodes its JSON.
//
//  Every subcommand accepts --schema-version. Pinning it means an Apple schema
//  revision fails loudly here rather than silently mis-decoding into a report
//  that looks fine and is wrong.
//

import Foundation

enum XCResultToolError: Error, CustomStringConvertible {
    case executionFailed(arguments: [String], status: Int32, stderr: String)
    case decodingFailed(arguments: [String], underlying: Error)

    var description: String {
        switch self {
        case let .executionFailed(arguments, status, stderr):
            return "xcresulttool \(arguments.joined(separator: " ")) exited \(status): \(stderr)"
        case let .decodingFailed(arguments, underlying):
            return "Could not decode xcresulttool \(arguments.joined(separator: " ")): \(underlying)"
        }
    }
}

struct XCResultToolClient {
    /// The schema this reader was written against. Bump deliberately, with a
    /// differential run, never as a reflex to a decode failure.
    static let schemaVersion = "0.1.0"

    let bundleURL: URL

    func run(_ arguments: [String]) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["xcresulttool"] + arguments + [
            "--path", bundleURL.path,
            "--schema-version", Self.schemaVersion,
        ]

        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        try process.run()

        // Drain before waiting: xcresulttool output routinely outgrows the
        // pipe buffer, and waiting first deadlocks when it does.
        var errorData = Data()
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global().async {
            errorData = err.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        let outputData = out.fileHandleForReading.readDataToEndOfFile()
        group.wait()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw XCResultToolError.executionFailed(
                arguments: arguments,
                status: process.terminationStatus,
                stderr: String(data: errorData, encoding: .utf8) ?? ""
            )
        }
        return outputData
    }

    func json<T: Decodable>(_ arguments: [String], as type: T.Type) throws -> T {
        let data = try run(arguments)
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw XCResultToolError.decodingFailed(arguments: arguments, underlying: error)
        }
    }

    /// Whether this toolchain still offers the `--legacy` commands.
    ///
    /// `xcresulttool version` prints
    /// `... (legacy commands format version: 3.56)` while they exist, and is
    /// expected to drop the parenthetical once they are removed.
    static let legacyCommandsAvailable: Bool = {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["xcresulttool", "version"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return false
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let text = String(data: data, encoding: .utf8) ?? ""
        return text.contains("legacy commands format version")
    }()
}
```

Note `--schema-version` is appended after the caller's arguments so callers pass
only the subcommand and its own options.

- [ ] **Step 4: Run tests to verify they pass**

```bash
swift test --filter XCResultToolClientTests
```

Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
swiftformat . && git add Sources/XCTestHTMLReportCore/Classes/ResultReading/Modern/ \
  Tests/XCTestHTMLReportTests/XCResultToolClientTests.swift
git commit -m "feat: add XCResultToolClient with pinned schema version"
```

---

## Task 7: New-format schema structs

**Files:**
- Create: `Sources/XCTestHTMLReportCore/Classes/ResultReading/Modern/TestResultsSchema.swift`
- Create: `Tests/XCTestHTMLReportTests/TestResultsSchemaTests.swift`

**Interfaces:**
- Produces: `TestResultsSummary`, `TestResultsTests`, `TestNode`,
  `TestActivities`, `ActivityNode`, `ActivityAttachment`, `AttachmentManifest`.
  Consumed by Tasks 8–10.

- [ ] **Step 1: Write the failing test**

```swift
//
//  TestResultsSchemaTests.swift
//

import XCTest
@testable import XCTestHTMLReportCore

final class TestResultsSchemaTests: XCTestCase {
    func testDecodesRepetitionNodes() throws {
        let json = """
        {"testNodes":[{"name":"MainScheme","nodeType":"Test Plan","result":"Failed",
        "children":[{"name":"testRetryOnFailure()","nodeType":"Test Case",
        "nodeIdentifier":"RetryTests/testRetryOnFailure()","result":"Passed",
        "durationInSeconds":0.068,"children":[
        {"name":"First Run","nodeType":"Repetition","nodeIdentifier":"1","result":"Failed",
        "durationInSeconds":0.078},
        {"name":"Retry 1","nodeType":"Repetition","nodeIdentifier":"2","result":"Passed",
        "durationInSeconds":0.059}]}]}],
        "devices":[],"testPlanConfigurations":[]}
        """
        let decoded = try JSONDecoder().decode(
            TestResultsTests.self, from: Data(json.utf8)
        )
        let testCase = try XCTUnwrap(decoded.testNodes?.first?.children?.first)
        XCTAssertEqual(testCase.nodeType, "Test Case")
        XCTAssertEqual(testCase.children?.count, 2)
        XCTAssertEqual(testCase.children?.map(\.nodeIdentifier), ["1", "2"])
    }

    func testDecodesActivityAttachments() throws {
        let json = """
        {"testIdentifier":"FirstSuite/testTwo()","testName":"testTwo()","testRuns":[
        {"activities":[{"title":"Start Test","startTime":1786425364.793,
        "isAssociatedWithFailure":false,"attachments":[
        {"name":"Screen Recording.mp4","payloadId":"0~abc",
        "uuid":"4DB9AD3F-E485-4F77-9771-8FAC7270E261","timestamp":1786425364.806,
        "lifetime":"deleteOnSuccess"}]}]}]}
        """
        let decoded = try JSONDecoder().decode(TestActivities.self, from: Data(json.utf8))
        let attachment = try XCTUnwrap(
            decoded.testRuns?.first?.activities?.first?.attachments?.first
        )
        XCTAssertEqual(attachment.uuid, "4DB9AD3F-E485-4F77-9771-8FAC7270E261")
        XCTAssertEqual(attachment.name, "Screen Recording.mp4")
    }
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
swift test --filter TestResultsSchemaTests
```

Expected: FAIL — `cannot find type 'TestResultsTests' in scope`.

- [ ] **Step 3: Implement the schema**

```swift
//
//  TestResultsSchema.swift
//  XCTestHTMLReportCore
//
//  Codable mirrors of `xcresulttool get test-results ...` and
//  `xcresulttool export attachments`. Field names match the JSON exactly, so
//  no CodingKeys are needed.
//
//  Almost everything is optional: xcresulttool omits empty collections and
//  inapplicable fields rather than emitting nulls, and a missing key must
//  degrade rather than fail the whole read.
//

import Foundation

struct TestResultsDevice: Decodable {
    let deviceId: String?
    let deviceName: String?
    let modelName: String?
    let osVersion: String?
    let platform: String?
}

struct TestResultsSummary: Decodable {
    let title: String?
    let environmentDescription: String?
    let totalTestCount: Int?
    let devicesAndConfigurations: [DeviceAndConfiguration]?

    struct DeviceAndConfiguration: Decodable {
        let device: TestResultsDevice?
    }
}

struct TestResultsTests: Decodable {
    let devices: [TestResultsDevice]?
    // Optional with an empty default: xcresulttool omits collection keys
    // rather than emitting empty arrays, and a bundle with no tests must
    // decode to an empty result rather than throwing keyNotFound.
    let testNodes: [TestNode]?
}

/// One node of the test tree. `nodeType` is the discriminator:
/// `Test Plan`, `UI test bundle`, `Unit test bundle`, `Test Suite`,
/// `Test Case`, `Repetition`, `Failure Message`.
struct TestNode: Decodable {
    let name: String?
    let nodeType: String?
    let nodeIdentifier: String?
    let nodeIdentifierURL: String?
    let result: String?
    let durationInSeconds: Double?
    let details: String?
    let children: [TestNode]?
}

struct TestActivities: Decodable {
    let testIdentifier: String?
    let testName: String?
    /// Optional for the same reason as `TestResultsTests.testNodes`: an
    /// omitted key must decode, not throw.
    let testRuns: [TestRun]?

    struct TestRun: Decodable {
        let device: TestResultsDevice?
        let activities: [ActivityNode]?
    }
}

struct ActivityNode: Decodable {
    let title: String?
    let startTime: Double?
    let isAssociatedWithFailure: Bool?
    let attachments: [ActivityAttachment]?
    let childActivities: [ActivityNode]?
}

struct ActivityAttachment: Decodable {
    let name: String?
    let payloadId: String?
    let uuid: String?
    let timestamp: Double?
    let lifetime: String?
}

/// `manifest.json` written by `xcresulttool export attachments`.
struct AttachmentManifestEntry: Decodable {
    let testIdentifier: String?
    let testIdentifierURL: String?
    let attachments: [ManifestAttachment]?

    struct ManifestAttachment: Decodable {
        let exportedFileName: String?
        let suggestedHumanReadableName: String?
        let isAssociatedWithFailure: Bool?
        let timestamp: Double?
    }
}

/// Section of `xcresulttool get log`. Note there is no `emittedOutput`; the
/// new format carries structured `messages` instead.
struct LogSection: Decodable {
    let title: String?
    let domainType: String?
    let duration: Double?
    let result: String?
    let messages: [LogMessage]?
    let subsections: [LogSection]?

    struct LogMessage: Decodable {
        let title: String?
        let shortTitle: String?
        let type: String?
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
swift test --filter TestResultsSchemaTests
```

Expected: PASS, 2 tests.

- [ ] **Step 5: Commit**

```bash
swiftformat . && git add Sources/XCTestHTMLReportCore/Classes/ResultReading/Modern/TestResultsSchema.swift \
  Tests/XCTestHTMLReportTests/TestResultsSchemaTests.swift
git commit -m "feat: add Codable schema for the new xcresulttool format"
```

---

## Task 8: `ModernResultReader` — tree, status, iterations

The parity-critical task. Two rules from the spec are load-bearing here.

**Files:**
- Create: `Sources/XCTestHTMLReportCore/Classes/ResultReading/Modern/ModernResultReader.swift`
- Create: `Tests/XCTestHTMLReportTests/ModernResultReaderTests.swift`

**Interfaces:**
- Consumes: `XCResultToolClient` (Task 6), schema (Task 7), `ParsedResult` (Task 3).
- Produces: `ModernResultReader(client:payloadStore:faultCollector:)` conforming
  to `ResultReader`. Task 9 supplies `payloadStore`; until then pass `nil`.

**Prerequisite — add the fault kind.** `activities(for:)` records
`.missingActivities`, which does not exist yet. Add it to `Fault.Kind` in
`Classes/Helpers/FaultCollector.swift`, alongside the existing cases:

```swift
/// The activity tree for a test could not be read, so the test appears in
/// the report with no activities. A genuine read failure, distinct from a
/// backend that structurally cannot provide a field.
case missingActivities
```

**Rule 1 — status mapping.** `Passed`→`Success`, `Failed`→`Failure`,
`Skipped`→`Skipped`, `Expected Failure`→`Expected Failure`. The last one maps
to `Status.unknown` downstream because `Status` has no matching raw value.
That is today's legacy behavior and must be reproduced, **not fixed**.

**Rule 2 — multi-repetition status.** A Test Case node carries its own
`result`, which is **not** the legacy status. `testRetryOnFailure()` has
`result: "Passed"` with children `Failed` then `Passed`; legacy reports
`.mixed`. When a Test Case has `Repetition` children, derive iterations from
them and **ignore the parent's `result`**. Only a childless Test Case uses its
own.

- [ ] **Step 1: Write the failing test**

```swift
//
//  ModernResultReaderTests.swift
//

import XCTest
@testable import XCTestHTMLReportCore

final class ModernResultReaderTests: XCTestCase {
    private func read(_ resource: String) throws -> ParsedResult {
        let url = try XCTUnwrap(
            Bundle.testBundle.url(forResource: resource, withExtension: "xcresult")
        )
        let reader = ModernResultReader(
            client: XCResultToolClient(bundleURL: url),
            payloadStore: nil,
            faultCollector: FaultCollector()
        )
        return try XCTUnwrap(reader.read())
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

    func testRepetitionsBecomeIterationsAndParentResultIsIgnored() throws {
        let retried = try XCTUnwrap(
            testCases(in: try read("RetryResults"))
                .first { $0.identifier == "RetryTests/testRetryOnFailure()" }
        )
        // The Test Case node says "Passed". Legacy reports mixed. Taking the
        // parent result here would silently turn a mixed test green.
        XCTAssertEqual(retried.iterations.count, 2)
        XCTAssertEqual(retried.iterations.map(\.iterationNumber), [1, 2])
        XCTAssertEqual(
            retried.iterations.map(\.statusRawValue), ["Failure", "Success"]
        )
    }

    func testStatusRawValuesMatchLegacyVocabulary() throws {
        let cases = testCases(in: try read("TestResults"))
        func status(_ identifier: String) throws -> String {
            try XCTUnwrap(cases.first { $0.identifier == identifier })
                .iterations[0].statusRawValue
        }
        XCTAssertEqual(try status("FirstSuite/testOne()"), "Success")
        XCTAssertEqual(try status("FirstSuite/testTwo()"), "Failure")
        XCTAssertEqual(try status("SampleAppUnitTests/testSkipped()"), "Skipped")
    }

    func testExpectedFailureIsPassedThroughUnmapped() throws {
        let unknownState = try XCTUnwrap(
            testCases(in: try read("RetryResults"))
                .first { $0.identifier == "RetryTests/testInUnknownState()" }
        )
        // Legacy emits "Expected Failure", which Status(rawValue:) does not
        // recognise and which therefore renders as .unknown. Preserve that.
        XCTAssertEqual(unknownState.iterations[0].statusRawValue, "Expected Failure")
        XCTAssertNil(Status(rawValue: "Expected Failure"))
    }

    func testTreeIsFlatWithoutLegacyWrapperGroups() throws {
        let result = try read("TestResults")
        let targets = result.runs.flatMap(\.testables).map(\.targetName).sorted()
        XCTAssertEqual(targets, ["SampleAppUITests", "SampleAppUnitTests"])

        let groupNames = result.runs
            .flatMap(\.testables)
            .flatMap(\.groups)
            .map(\.name)
        // Deliberately flat: no "Selected tests" / "All tests" / "*.xctest".
        XCTAssertFalse(groupNames.contains("Selected tests"))
        XCTAssertFalse(groupNames.contains("All tests"))
        XCTAssertTrue(groupNames.contains("FirstSuite"))
        XCTAssertTrue(groupNames.contains("SwiftTestingSuite"))
    }
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
swift test --filter ModernResultReaderTests
```

Expected: FAIL — `cannot find 'ModernResultReader' in scope`.

- [ ] **Step 3: Implement the reader**

```swift
//
//  ModernResultReader.swift
//  XCTestHTMLReportCore
//
//  Builds ParsedResult from `xcresulttool get test-results`.
//
//  The new tree omits the two wrapper levels legacy interposes
//  ("Selected tests" / "All tests", then "<target>.xctest"). We render the
//  natural flat tree rather than synthesising them: whether the wrapper is
//  "Selected tests" or "All tests" depends on run filtering, which the new
//  format does not expose, so one of the two labels would always be invented.
//

import Foundation

struct ModernResultReader: ResultReader {
    let client: XCResultToolClient
    let payloadStore: ModernPayloadStore?
    let faultCollector: FaultCollector

    func read() -> ParsedResult? {
        do {
            let tests = try client.json(
                ["get", "test-results", "tests"], as: TestResultsTests.self
            )
            let device = tests.devices?.first
            let destination = ParsedDestination(
                displayName: device?.deviceName ?? "",
                deviceIdentifier: device?.deviceId ?? "",
                modelName: device?.modelName ?? "",
                operatingSystemVersion: device?.osVersion ?? ""
            )
            let testables = (tests.testNodes ?? [])
                .flatMap { $0.children ?? [] }
                .filter { Self.bundleNodeTypes.contains($0.nodeType ?? "") }
                .map { bundle in
                    ParsedTestable(
                        targetName: bundle.name ?? "",
                        groups: (bundle.children ?? []).map(parseGroup)
                    )
                }
            return ParsedResult(runs: [
                ParsedRun(
                    destination: destination,
                    logReference: "action",
                    testables: testables
                ),
            ])
        } catch {
            Logger.warning("Modern reader failed: \(error)")
            return nil
        }
    }

    private static let bundleNodeTypes: Set<String> = [
        "UI test bundle", "Unit test bundle",
    ]

    private func parseGroup(_ node: TestNode) -> ParsedGroup {
        let children: [ParsedNode] = (node.children ?? []).compactMap { child in
            switch child.nodeType {
            case "Test Case": return .testCase(parseTestCase(child))
            case "Test Suite": return .group(parseGroup(child))
            default: return nil
            }
        }
        return ParsedGroup(
            name: node.name ?? "---group-name-not-found---",
            identifier: node.nodeIdentifier ?? node.name ?? "---group-identifier-not-found---",
            duration: node.durationInSeconds ?? 0,
            children: children
        )
    }

    private func parseTestCase(_ node: TestNode) -> ParsedTestCase {
        let repetitions = (node.children ?? []).filter { $0.nodeType == "Repetition" }
        let identifier = node.nodeIdentifier ?? ""

        let iterations: [ParsedIteration]
        if repetitions.isEmpty {
            iterations = [ParsedIteration(
                iterationNumber: nil,
                statusRawValue: Self.status(node.result),
                duration: node.durationInSeconds ?? 0,
                activities: activities(for: identifier, iteration: nil)
            )]
        } else {
            // The parent node's own `result` summarises the retries and is not
            // the legacy status: a test that failed then passed reports
            // "Passed" here while legacy reports mixed. Derive from children.
            iterations = repetitions.enumerated().map { index, repetition in
                ParsedIteration(
                    iterationNumber: repetition.nodeIdentifier.flatMap(Int.init)
                        ?? (index + 1),
                    statusRawValue: Self.status(repetition.result),
                    duration: repetition.durationInSeconds ?? 0,
                    activities: activities(for: identifier, iteration: index)
                )
            }
        }

        return ParsedTestCase(
            name: node.name ?? "",
            identifier: identifier,
            iterations: iterations
        )
    }

    /// Maps the new vocabulary onto the legacy raw values `Status` parses.
    /// `Expected Failure` is passed through unchanged: `Status` has no case
    /// for it, so it becomes `.unknown` — which is exactly what the legacy
    /// backend does today.
    private static func status(_ result: String?) -> String {
        switch result {
        case "Passed": return "Success"
        case "Failed": return "Failure"
        case "Skipped": return "Skipped"
        case let other: return other ?? ""
        }
    }

    /// One `activities` call per test. `testRuns` holds one entry per
    /// repetition, in order.
    private func activities(for identifier: String, iteration: Int?) -> [ParsedActivity] {
        guard !identifier.isEmpty else {
            return []
        }
        do {
            let document = try client.json(
                ["get", "test-results", "activities", "--test-id", identifier],
                as: TestActivities.self
            )
            let runs = document.testRuns ?? []
            let run = iteration.map { index in
                runs.indices.contains(index) ? runs[index] : nil
            } ?? runs.first
            return (run??.activities ?? []).map(parseActivity)
        } catch {
            // A failed activities query is a genuine read failure, not a
            // format limitation: the test renders with no activities at all.
            // Without a fault the CLI would exit 0 on a visibly gutted report.
            Logger.warning("Can't read activities for \(identifier): \(error)")
            faultCollector.record(.missingActivities, identifier)
            return []
        }
    }

    private func parseActivity(_ node: ActivityNode) -> ParsedActivity {
        ParsedActivity(
            title: node.title ?? "",
            // The new format carries no activity type. Absent, not empty.
            activityType: nil,
            isFailure: node.isAssociatedWithFailure ?? false,
            start: node.startTime.map { Date(timeIntervalSince1970: $0) },
            // The new format reports no finish time, so activity duration is
            // not derivable. Left nil rather than guessed from siblings.
            finish: nil,
            attachments: (node.attachments ?? []).map(parseAttachment),
            subActivities: (node.childActivities ?? []).map(parseActivity)
        )
    }

    private func parseAttachment(_ attachment: ActivityAttachment) -> ParsedAttachment {
        let exported = attachment.uuid.flatMap { payloadStore?.exportedFileName(uuid: $0) }
        return ParsedAttachment(
            // `name` in the new format holds what legacy calls `filename`; the
            // user-supplied name is not exposed. Report it as filename only.
            name: nil,
            filename: attachment.name,
            uniformTypeIdentifier: nil,
            filenameExtension: exported.map { ($0 as NSString).pathExtension },
            payloadReference: attachment.uuid
        )
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
swift test --filter ModernResultReaderTests
```

Expected: PASS, 4 tests. If `testRepetitionsBecomeIterations` reports one
iteration, `repetitions` is not matching — confirm `nodeType` is exactly
`"Repetition"`.

- [ ] **Step 5: Commit**

```bash
swiftformat . && git add Sources/XCTestHTMLReportCore/Classes/ResultReading/Modern/ModernResultReader.swift \
  Tests/XCTestHTMLReportTests/ModernResultReaderTests.swift
git commit -m "feat: add ModernResultReader for the new xcresulttool format"
```

---

## Task 9: `ModernPayloadStore` — attachments

**Files:**
- Create: `Sources/XCTestHTMLReportCore/Classes/ResultReading/Modern/ModernPayloadStore.swift`
- Create: `Tests/XCTestHTMLReportTests/ModernPayloadStoreTests.swift`

**Interfaces:**
- Produces: `ModernPayloadStore(client:bundleURL:faultCollector:)` conforming
  to `PayloadProviding`, plus `func exportedFileName(uuid: String) -> String?`
  used by Task 8.

**Mechanism.** `xcresulttool export attachments --output-path D` writes every
attachment as `<attachment-uuid>.<ext>` plus `manifest.json`, in one call
(measured 0.05s on `TestResults`). The join is
`activities[].attachments[].uuid` ↔ the basename of
`manifest[].attachments[].exportedFileName`; verified on `TestResults` as
`4DB9AD3F-…-8FAC7270E261` ↔ `4DB9AD3F-…-8FAC7270E261.mp4`.

Export lazily, once, on first use. Unlike the legacy path there is no shared
temp file per id, so no per-id lock is needed — but the one-shot export itself
must be guarded so concurrent parsing does not run it twice.

- [ ] **Step 1: Write the failing test**

```swift
//
//  ModernPayloadStoreTests.swift
//

import XCTest
@testable import XCTestHTMLReportCore

final class ModernPayloadStoreTests: XCTestCase {
    private func store(for resource: String) throws -> (ModernPayloadStore, URL) {
        let source = try XCTUnwrap(
            Bundle.testBundle.url(forResource: resource, withExtension: "xcresult")
        )
        // Copy: the store writes exported payloads into the bundle directory.
        let copy = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent(source.lastPathComponent)
        try FileManager.default.createDirectory(
            at: copy.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try FileManager.default.copyItem(at: source, to: copy)
        return (
            ModernPayloadStore(
                client: XCResultToolClient(bundleURL: copy),
                bundleURL: copy,
                faultCollector: FaultCollector()
            ),
            copy
        )
    }

    func testResolvesExportedFileNameByUUID() throws {
        let (store, bundle) = try store(for: "TestResults")
        let url = try XCTUnwrap(
            XCResultToolClient(bundleURL: bundle)
                .json(["get", "test-results", "activities",
                       "--test-id", "FirstSuite/testAttachHtmlData()"],
                      as: TestActivities.self)
        )
        let uuid = try XCTUnwrap(
            url.testRuns?.first?.activities?
                .compactMap { $0.attachments?.first?.uuid }.first
        )
        let name = try XCTUnwrap(store.exportedFileName(uuid: uuid))
        XCTAssertTrue(name.hasPrefix(uuid), "Exported file is named after the uuid")
        XCTAssertTrue(name.hasSuffix(".html"))
    }

    func testExportPayloadWritesNonEmptyFileIntoBundle() throws {
        let (store, bundle) = try store(for: "TestResults")
        let document = try XCResultToolClient(bundleURL: bundle).json(
            ["get", "test-results", "activities",
             "--test-id", "FirstSuite/testAttachHtmlData()"],
            as: TestActivities.self
        )
        let uuid = try XCTUnwrap(
            document.testRuns?.first?.activities?
                .compactMap { $0.attachments?.first?.uuid }.first
        )
        let relative = try XCTUnwrap(
            store.exportPayload(reference: uuid, fileName: "attached.html")
        )
        let written = bundle.appendingPathComponent(relative.lastPathComponent)
        let data = try Data(contentsOf: written)
        XCTAssertFalse(data.isEmpty)
        XCTAssertTrue(
            String(decoding: data, as: UTF8.self).contains("Sample attachment body")
        )
    }

    func testUnknownReferenceReturnsNil() throws {
        let (store, _) = try store(for: "SanityResults")
        XCTAssertNil(store.exportPayload(reference: "not-a-uuid", fileName: nil))
    }
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
swift test --filter ModernPayloadStoreTests
```

Expected: FAIL — `cannot find 'ModernPayloadStore' in scope`.

- [ ] **Step 3: Implement the store**

```swift
//
//  ModernPayloadStore.swift
//  XCTestHTMLReportCore
//
//  `xcresulttool export attachments` exports every attachment in the bundle in
//  a single call, naming each file after its attachment uuid and writing a
//  manifest alongside. That replaces the legacy one-subprocess-per-payload
//  export, and with it the per-id locking the legacy path needs: there is no
//  shared temp path to race on here. Only the one-shot export itself is
//  guarded, so concurrent parsing does not trigger it twice.
//

import Foundation

final class ModernPayloadStore: PayloadProviding {
    private let client: XCResultToolClient
    private let bundleURL: URL
    private let relativeURL: URL
    private let faultCollector: FaultCollector

    private let lock = NSLock()
    private var exportDirectory: URL?
    private var fileNamesByUUID: [String: String] = [:]
    private var exportAttempted = false

    // `export attachments` writes a full copy of every attachment, including
    // screen recordings. Without this the temp directory outlives the process
    // and each run leaks tens of megabytes into NSTemporaryDirectory().
    deinit {
        if let directory = exportDirectory {
            try? FileManager.default.removeItem(at: directory)
        }
    }

    init(client: XCResultToolClient, bundleURL: URL, faultCollector: FaultCollector) {
        self.client = client
        self.bundleURL = bundleURL
        self.faultCollector = faultCollector
        relativeURL = URL(fileURLWithPath: bundleURL.lastPathComponent)
    }

    func exportedFileName(uuid: String) -> String? {
        ensureExported()
        return lock.withLock { fileNamesByUUID[uuid] }
    }

    func exportPayload(reference: String, fileName: String?) -> URL? {
        guard let source = sourceURL(for: reference) else {
            faultCollector.record(.payloadExportFailed, "attachment \(reference)")
            return nil
        }
        let resolved = fileName ?? source.lastPathComponent
        let destination = bundleURL.appendingPathComponent(resolved)
        do {
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.copyItem(at: source, to: destination)
            return relativeURL.appendingPathComponent(resolved)
        } catch {
            if FileManager.default.fileExists(atPath: destination.path) {
                return relativeURL.appendingPathComponent(resolved)
            }
            Logger.warning("Can't copy \(source) to \(destination): \(error)")
            faultCollector.record(.payloadExportFailed, "attachment \(reference)")
            return nil
        }
    }

    func exportPayloadData(reference: String) -> Data? {
        guard let source = sourceURL(for: reference) else {
            faultCollector.record(.payloadExportFailed, "attachment \(reference)")
            return nil
        }
        do {
            return try Data(contentsOf: source)
        } catch {
            // An exported file we cannot read is a real failure, not a format
            // limitation, so it earns a fault rather than a silent nil.
            Logger.warning("Can't read exported attachment \(source): \(error)")
            faultCollector.record(.payloadExportFailed, "attachment \(reference)")
            return nil
        }
    }

    func exportLogs(reference: String) -> URL? {
        guard let text = logText(reference: reference) else {
            return nil
        }
        let fileName = "\(reference).log"
        let destination = bundleURL.appendingPathComponent(fileName)
        do {
            try? FileManager.default.removeItem(at: destination)
            try text.write(to: destination, atomically: true, encoding: .utf8)
            return relativeURL.appendingPathComponent(fileName)
        } catch {
            Logger.warning("Can't write log to \(destination): \(error)")
            return nil
        }
    }

    func exportLogsData(reference: String) -> Data? {
        logText(reference: reference)?.data(using: .utf8)
    }

    // MARK: - Private

    private func sourceURL(for uuid: String) -> URL? {
        ensureExported()
        return lock.withLock {
            guard let directory = exportDirectory, let name = fileNamesByUUID[uuid] else {
                return nil
            }
            return directory.appendingPathComponent(name)
        }
    }

    private func ensureExported() {
        lock.lock()
        defer { lock.unlock() }
        guard !exportAttempted else {
            return
        }
        exportAttempted = true

        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("xchtmlreport-attachments-\(UUID().uuidString)")
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true
            )
            _ = try client.run([
                "export", "attachments", "--output-path", directory.path,
            ])
            let manifestData = try Data(
                contentsOf: directory.appendingPathComponent("manifest.json")
            )
            let manifest = try JSONDecoder().decode(
                [AttachmentManifestEntry].self, from: manifestData
            )
            exportDirectory = directory
            for entry in manifest {
                for attachment in entry.attachments ?? [] {
                    guard let file = attachment.exportedFileName else {
                        continue
                    }
                    // Files are named "<attachment-uuid>.<ext>"; the uuid is
                    // the join key back to the activities document.
                    fileNamesByUUID[(file as NSString).deletingPathExtension] = file
                }
            }
        } catch {
            Logger.warning("Can't export attachments: \(error)")
            faultCollector.record(.payloadExportFailed, "attachment export")
        }
    }

    private func logText(reference: String) -> String? {
        do {
            let section = try client.json(
                ["get", "log", "--type", reference], as: LogSection.self
            )
            return Self.format(section)
        } catch {
            Logger.warning("Can't get logs (\(reference)): \(error)")
            faultCollector.record(.logExportFailed, "log \(reference)")
            return nil
        }
    }

    /// The new format has no `emittedOutput`, so the run log is rendered from
    /// the structured `messages` instead, keeping the legacy indentation shape.
    private static func format(_ section: LogSection, depth: Int = 0) -> String {
        let indent = String(repeating: "\t", count: depth)
        var lines = ["\(indent)-------- \(section.title ?? "") --------"]
        for message in section.messages ?? [] {
            lines.append("\(indent)\(message.title ?? message.shortTitle ?? "")")
        }
        for subsection in section.subsections ?? [] {
            lines.append(format(subsection, depth: depth + 1))
        }
        return lines.joined(separator: "\n")
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
```

Note: remove the duplicated `self.faultCollector` assignment in `init` — it is
shown above only to flag that the property is assigned once; SwiftLint will
catch the duplicate.

- [ ] **Step 4: Run tests to verify they pass**

```bash
swift test --filter ModernPayloadStoreTests
```

Expected: PASS, 3 tests.

- [ ] **Step 5: Wire the store into the reader and re-run Task 8's tests**

Pass a real `ModernPayloadStore` where Task 8 passed `nil`.

```bash
swift test --filter "ModernResultReaderTests|ModernPayloadStoreTests"
```

Expected: PASS, 7 tests.

- [ ] **Step 6: Commit**

```bash
swiftformat . && git add Sources/XCTestHTMLReportCore/Classes/ResultReading/Modern/ModernPayloadStore.swift \
  Tests/XCTestHTMLReportTests/ModernPayloadStoreTests.swift
git commit -m "feat: export attachments through the modern xcresulttool path"
```

---

## Task 10: Attachment typing without a UTI

The modern backend has no `uniformTypeIdentifier`. `AttachmentType` is built
from one, so it needs an extension-based path.

**Files:**
- Modify: `Sources/XCTestHTMLReportCore/Classes/Models/Attachment.swift`
- Create: `Tests/XCTestHTMLReportTests/AttachmentTypeTests.swift`

**Interfaces:**
- Produces: `AttachmentType.init(filenameExtension:)`.

- [ ] **Step 1: Write the failing test**

```swift
//
//  AttachmentTypeTests.swift
//

import XCTest
@testable import XCTestHTMLReportCore

final class AttachmentTypeTests: XCTestCase {
    func testMapsExtensionsToTypes() {
        XCTAssertEqual(AttachmentType(filenameExtension: "png"), .png)
        XCTAssertEqual(AttachmentType(filenameExtension: "PNG"), .png)
        XCTAssertEqual(AttachmentType(filenameExtension: "jpeg"), .jpeg)
        XCTAssertEqual(AttachmentType(filenameExtension: "jpg"), .jpeg)
        XCTAssertEqual(AttachmentType(filenameExtension: "mp4"), .mp4)
        XCTAssertEqual(AttachmentType(filenameExtension: "txt"), .text)
        XCTAssertEqual(AttachmentType(filenameExtension: "log"), .log)
        XCTAssertEqual(AttachmentType(filenameExtension: "html"), .html)
        XCTAssertEqual(AttachmentType(filenameExtension: "gif"), .gif)
        XCTAssertEqual(AttachmentType(filenameExtension: "heic"), .heic)
        XCTAssertEqual(AttachmentType(filenameExtension: "zip"), .zip)
    }

    func testUnrecognisedExtensionIsUnknown() {
        XCTAssertEqual(AttachmentType(filenameExtension: "xyz"), .unknown)
        XCTAssertEqual(AttachmentType(filenameExtension: ""), .unknown)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
swift test --filter AttachmentTypeTests
```

Expected: FAIL — no such initializer.

- [ ] **Step 3: Implement it**

Add to `AttachmentType` in `Attachment.swift`:

```swift
/// Builds a type from a file extension, for backends that report no UTI.
/// The modern xcresulttool format names exported attachments
/// `<uuid>.<ext>` and does not carry a uniform type identifier.
init(filenameExtension: String) {
    switch filenameExtension.lowercased() {
    case "png": self = .png
    case "jpeg", "jpg": self = .jpeg
    case "heic": self = .heic
    case "gif": self = .gif
    case "mp4": self = .mp4
    case "txt": self = .text
    case "log": self = .log
    case "html", "htm": self = .html
    case "zip": self = .zip
    default: self = .unknown
    }
}
```

And in `Attachment.init(attachment:...)`, prefer the UTI and fall back:

```swift
if let identifier = attachment.uniformTypeIdentifier {
    type = AttachmentType(rawValue: identifier) ?? .unknown
} else if let ext = attachment.filenameExtension {
    type = AttachmentType(filenameExtension: ext)
} else {
    type = .unknown
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
swift test --filter AttachmentTypeTests && swift test 2>&1 | tail -5
```

Expected: 2 new tests PASS; the full suite stays green.

- [ ] **Step 5: Commit**

```bash
swiftformat . && git add Sources/XCTestHTMLReportCore/Classes/Models/Attachment.swift \
  Tests/XCTestHTMLReportTests/AttachmentTypeTests.swift
git commit -m "feat: derive attachment type from file extension when no UTI is available"
```

---

## Task 11: Backend selection and the `--result-reader` flag

**Files:**
- Create: `Sources/XCTestHTMLReportCore/Classes/ResultReading/ResultBackend.swift`
- Modify: `Sources/XCTestHTMLReportCore/Classes/Models/Summary.swift`
- Modify: `Sources/XCTestHTMLReport/XCTestHtmlReport.swift`
- Create: `Tests/XCTestHTMLReportTests/ResultBackendTests.swift`

**Interfaces:**
- Produces: `public enum ResultBackend: String { case auto, legacy, modern }`
  with `func resolved() -> ResultBackend`, and a new
  `Summary.init(..., backend: ResultBackend = .auto)` parameter appended after
  `faultCollector`.

- [ ] **Step 1: Write the failing test**

```swift
//
//  ResultBackendTests.swift
//

import XCTest
@testable import XCTestHTMLReportCore

final class ResultBackendTests: XCTestCase {
    func testModernAlwaysResolvesToModern() {
        XCTAssertEqual(ResultBackend.modern.resolved(), .modern)
    }

    func testLegacyDemotesWhenTheToolchainDropsIt() {
        // Conditional rather than absolute: asserting .legacy -> .legacy
        // outright would start failing the day Apple removes the commands,
        // which is precisely when this fallback needs to work.
        if XCResultToolClient.legacyCommandsAvailable {
            XCTAssertEqual(ResultBackend.legacy.resolved(), .legacy)
        } else {
            XCTAssertEqual(ResultBackend.legacy.resolved(), .modern)
        }
    }

    func testAutoNeverResolvesToAuto() {
        XCTAssertNotEqual(ResultBackend.auto.resolved(), .auto)
    }

    func testAutoPrefersLegacyWhileTheToolchainOffersIt() {
        // Conditional on the host toolchain rather than asserted outright, so
        // this keeps passing rather than becoming a time bomb after removal.
        if XCResultToolClient.legacyCommandsAvailable {
            XCTAssertEqual(ResultBackend.auto.resolved(), .legacy)
        } else {
            XCTAssertEqual(ResultBackend.auto.resolved(), .modern)
        }
    }

    func testBothBackendsProduceAReportForTheSameBundle() throws {
        let url = try XCTUnwrap(
            Bundle.testBundle.url(forResource: "SanityResults", withExtension: "xcresult")
        )
        for backend in [ResultBackend.legacy, .modern] {
            let summary = Summary(
                resultPaths: [url.path],
                renderingMode: .linking,
                downsizeImagesEnabled: false,
                downsizeScaleFactor: 0.5,
                backend: backend
            )
            XCTAssertFalse(
                summary.generatedHtmlReport().isEmpty,
                "\(backend) produced no report"
            )
            // Format limitations must never be recorded as faults; if they
            // were, every modern run would exit 3.
            XCTAssertEqual(summary.faults, [], "\(backend) reported faults")
        }
    }
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
swift test --filter ResultBackendTests
```

Expected: FAIL — `cannot find 'ResultBackend' in scope`.

- [ ] **Step 3: Implement backend selection**

```swift
//
//  ResultBackend.swift
//  XCTestHTMLReportCore
//

import Foundation

/// Which reader parses result bundles.
public enum ResultBackend: String, CaseIterable {
    /// Prefer `legacy` while the toolchain still offers the legacy commands.
    case auto
    case legacy
    case modern

    /// Never returns `.auto`.
    ///
    /// `.legacy` is honoured only when the toolchain still offers the legacy
    /// commands. An explicit `--result-reader legacy` on a toolchain without
    /// them demotes to `.modern` rather than failing every read: the spec's
    /// rule is that a legacy command failing degrades to working, not broken.
    public func resolved() -> ResultBackend {
        switch self {
        case .modern:
            return .modern
        case .legacy, .auto:
            guard XCResultToolClient.legacyCommandsAvailable else {
                if self == .legacy {
                    Logger.warning(
                        "This toolchain has no legacy xcresulttool commands; "
                            + "falling back to the modern reader."
                    )
                }
                return .modern
            }
            return .legacy
        }
    }
}
```

In `Summary.init`, build the reader and payload provider per backend:

```swift
let resolved = backend.resolved()
let client = XCResultToolClient(bundleURL: url)
let reader: ResultReader
let payloads: PayloadProviding
switch resolved {
case .legacy, .auto:
    reader = LegacyResultReader(file: resultFile)
    payloads = resultFile
case .modern:
    let store = ModernPayloadStore(
        client: client, bundleURL: url, faultCollector: faultCollector
    )
    reader = ModernResultReader(
        client: client, payloadStore: store, faultCollector: faultCollector
    )
    payloads = store
}
```

`Run`, `Activity`, and `Attachment` take `PayloadProviding` instead of
`ResultFile`. `Run.file` stays a `ResultFile` because `removeUnattachedFiles`
reads `run.file.url`.

Add the CLI flag in `SummaryOptions`:

```swift
@Option(
    name: .long,
    help: ArgumentHelp(
        "Which result reader to use: auto, legacy, or modern. Defaults to auto, which prefers the legacy reader while the toolchain still supports it."
    )
)
var resultReader: ResultBackend = .auto
```

plus the conformance next to the existing `RenderingMode` one:

```swift
extension ResultBackend: ExpressibleByArgument {}
```

Then thread it into `run()`. Declaring the option without passing it leaves a
flag that parses, validates, and does nothing:

```swift
let summary = Summary(
    resultPaths: summaryOptions.finalResults,
    renderingMode: summaryOptions.finalRenderingMode,
    downsizeImagesEnabled: summaryOptions.downsizeImages,
    downsizeScaleFactor: summaryOptions.downsizeScaleFactor,
    faultCollector: faultCollector,
    backend: summaryOptions.resultReader
)
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
swift test --filter ResultBackendTests && swift test 2>&1 | tail -5
```

Expected: 4 new tests PASS; full suite green.

**If `testBothBackendsProduceAReportForTheSameBundle` fails on the faults
assertion**, the modern backend is recording format limitations as faults. Fix
the recording site, not the assertion — this is the failure mode the spec calls
out as the easiest way to get the migration wrong.

- [ ] **Step 5: Verify the flag end to end**

```bash
set -o pipefail
swift build
for reader in legacy modern; do
  .build/debug/xchtmlreport --result-reader "$reader" \
    Tests/XCTestHTMLReportTests/Resources/TestResults.xcresult \
    -o "/tmp/check-$reader" >/dev/null
  echo "$reader exit=$? groups=$(grep -c 'test-summary-group' "/tmp/check-$reader/index.html")"
done
```

Expected: both exit 0. The two group counts must **differ** — legacy renders the
extra `Selected tests` / `*.xctest` wrapper levels and modern does not. Equal
counts mean the flag is not reaching `Summary` and both runs used one backend.

- [ ] **Step 6: Commit**

```bash
swiftformat . && git add -A
git commit -m "feat: select the result reader at runtime with --result-reader"
```

---

## Task 12: The differential test

What actually proves the migration. Runs both readers over one bundle and holds
the diff to a declared list.

**Files:**
- Create: `Tests/XCTestHTMLReportTests/DifferentialTests.swift`
- Create: `Tests/XCTestHTMLReportTests/Resources/differential-allowlist.json`
- Modify: `Package.swift` (add the allow-list as a test resource)

**Interfaces:**
- Consumes: `normalizeReport(_:)` (Task 1), `ResultBackend` (Task 11).

- [ ] **Step 1: Write the allow-list**

`Tests/XCTestHTMLReportTests/Resources/differential-allowlist.json`:

```json
{
  "comment": "Each entry names one field the modern xcresulttool format does not provide, and the masking rule that removes its effect from a rendered report. The differential test masks BOTH renders with every rule here and then requires them to be byte-identical: after the declared losses are removed, nothing else may differ. Adding an entry means accepting a permanent difference between the backends — a design decision, not a way to quiet a failing test.",
  "knownLosses": [
    {
      "rule": "activityTypeClasses",
      "field": "activity activityType",
      "effect": "Activity CSS classes are absent on the modern backend; only assertion-failure styling survives, via isAssociatedWithFailure. Rendered into `<div class=\"activity [[ACTIVITY_TYPE_CLASS]] ...\">`."
    },
    {
      "rule": "durations",
      "field": "activity finish time",
      "effect": "Per-activity durations render as 0s on the modern backend, which reports only a start time. Rendered as the bare `(0.00s)` suffix in `[[TITLE]] ([[TIME]])`, with no distinguishing element."
    },
    {
      "rule": "attachmentDisplayNames",
      "field": "attachment user-supplied name",
      "effect": "Attachment display names fall back to the type-derived label (Screenshot, Video, File) on the modern backend, because the new format exposes only the generated filename."
    },
    {
      "rule": "failureTitlePrefix",
      "field": "failure file and line",
      "effect": "Failure activity titles are the pre-joined message rather than '<issueType> at <file>:<line>:<message>'."
    },
    {
      "rule": "wrapperGroups",
      "field": "test tree wrapper groups",
      "effect": "The modern tree omits the legacy 'Selected tests' / 'All tests' and '<target>.xctest' wrapper levels."
    }
  ]
}
```

**Why masking rather than per-line markers.** The first draft of this plan
matched differing lines against literal marker strings. That does not work:
checked against `HTMLTemplates.swift`, activity durations render as a bare
`([[TIME]])` suffix and attachment names as bare text, neither carrying a class
to key on — only the activity type classes and the wrapper group names are
matchable literals. Masking inverts the test into the stronger form anyway:
instead of "every difference resembles something we declared", it asserts
"after removing exactly what we declared, there is no difference at all."

- [ ] **Step 2: Register the resource**

In `Package.swift`, add to the test target's `resources` array:

```swift
.process("Resources/differential-allowlist.json"),
```

- [ ] **Step 3: Write the known-loss masker**

`Tests/XCTestHTMLReportTests/KnownLossMasker.swift`:

```swift
//
//  KnownLossMasker.swift
//
//  Removes exactly the differences declared in differential-allowlist.json
//  from a rendered report, so the differential test can assert that what
//  remains is identical across backends.
//
//  Each rule here corresponds 1:1 to an allow-list entry, by name. Adding a
//  rule without adding the entry (or vice versa) fails
//  testEveryAllowListRuleIsImplemented.
//

import Foundation

enum KnownLossMasker {
    static let implementedRules: Set<String> = [
        "activityTypeClasses",
        "durations",
        "attachmentDisplayNames",
        "failureTitlePrefix",
        "wrapperGroups",
    ]

    static func mask(_ html: String, rules: [String]) -> String {
        var masked = html
        for rule in rules {
            masked = apply(rule, to: masked)
        }
        // Collapse whitespace-only differences left behind by the removals.
        return masked
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    private static func apply(_ rule: String, to html: String) -> String {
        switch rule {
        case "activityTypeClasses":
            // `<div class="activity activity-user-created no-drop-down">`
            return replace(html, #"activity-(internal|user-created|skipped-test|delete-attachment|assertion-failure)"#, with: "")
        case "durations":
            // Bare `(1.23s)` / `(0.00s)` suffixes from `[[TITLE]] ([[TIME]])`.
            return replace(html, #"\(\d+\.\d+s\)"#, with: "(DURATION)")
        case "attachmentDisplayNames":
            // The `[[NAME]]` line inside `<p class="attachment list-item">`.
            return replace(
                html,
                #"(<p class="attachment[^"]*">\n)[^\n<]+\n"#,
                with: "$1ATTACHMENT_NAME\n"
            )
        case "failureTitlePrefix":
            // `Assertion Failure at File.swift:76:` prefixed onto the message.
            return replace(html, #"[A-Za-z ]+ at [^\s:]+:\d+:"#, with: "")
        case "wrapperGroups":
            // Legacy-only `Selected tests` / `All tests` / `<target>.xctest`
            // group headings, and the div nesting they introduce.
            return html
                .split(separator: "\n")
                .filter { line in
                    !line.contains("Selected tests")
                        && !line.contains("All tests")
                        && !line.contains(".xctest")
                }
                .joined(separator: "\n")
        default:
            return html
        }
    }

    private static func replace(
        _ text: String, _ pattern: String, with template: String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text
        }
        return regex.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text),
            withTemplate: template
        )
    }
}
```

The `wrapperGroups` rule drops whole lines, which also drops the `<div>` nesting
those groups open. That makes the masked comparison insensitive to indentation
depth in the test tree — acceptable, because the tree's *content* is asserted
exactly by `testStatusesAndCountsMatchAcrossBackends`, and its shape is the
declared difference. If Step 5 shows this rule swallowing more than the wrapper
lines, tighten it to match the group `<div>` and its matching close rather than
loosening the assertions it protects.

- [ ] **Step 4: Write the differential test**

```swift
//
//  DifferentialTests.swift
//
//  Renders each fixture through both readers and holds the difference to the
//  declared allow-list. This is only possible while xcresulttool supports both
//  formats; it skips itself, loudly, once it does not.
//

import XCTest
@testable import XCTestHTMLReportCore

final class DifferentialTests: XCTestCase {
    private static let fixtures = ["TestResults", "SanityResults", "RetryResults"]

    private struct AllowList: Decodable {
        struct Loss: Decodable {
            let rule: String
            let field: String
            let effect: String
        }

        let knownLosses: [Loss]
    }

    private func allowList() throws -> AllowList {
        let url = try XCTUnwrap(
            Bundle.testBundle.url(
                forResource: "differential-allowlist", withExtension: "json"
            )
        )
        return try JSONDecoder().decode(AllowList.self, from: Data(contentsOf: url))
    }

    private func summary(_ resource: String, _ backend: ResultBackend) throws -> Summary {
        let url = try XCTUnwrap(
            Bundle.testBundle.url(forResource: resource, withExtension: "xcresult")
        )
        return Summary(
            resultPaths: [url.path],
            renderingMode: .linking,
            downsizeImagesEnabled: false,
            downsizeScaleFactor: 0.5,
            backend: backend
        )
    }

    private func requireBothBackends() throws {
        guard XCResultToolClient.legacyCommandsAvailable else {
            throw XCTSkip(
                "Toolchain has no legacy commands; the differential cannot run. "
                    + "Delete LegacyResultReader and this test together."
            )
        }
    }

    /// Counts and statuses must match exactly. These are the assertions that
    /// would catch the multi-repetition status regression.
    func testStatusesAndCountsMatchAcrossBackends() throws {
        try requireBothBackends()
        for fixture in Self.fixtures {
            let legacy = try summary(fixture, .legacy)
            let modern = try summary(fixture, .modern)

            func statuses(_ summary: Summary) -> [String: String] {
                Dictionary(
                    summary.runs.flatMap(\.allTests)
                        .map { ($0.identifier, $0.status.rawValue) },
                    uniquingKeysWith: { first, _ in first }
                )
            }
            XCTAssertEqual(
                statuses(legacy), statuses(modern),
                "\(fixture): identifier→status differs between backends"
            )

            for (legacyRun, modernRun) in zip(legacy.runs, modern.runs) {
                XCTAssertEqual(
                    legacyRun.numberOfTests, modernRun.numberOfTests, "\(fixture): total"
                )
                XCTAssertEqual(
                    legacyRun.numberOfPassedTests, modernRun.numberOfPassedTests,
                    "\(fixture): passed"
                )
                XCTAssertEqual(
                    legacyRun.numberOfFailedTests, modernRun.numberOfFailedTests,
                    "\(fixture): failed"
                )
                XCTAssertEqual(
                    legacyRun.numberOfSkippedTests, modernRun.numberOfSkippedTests,
                    "\(fixture): skipped"
                )
                XCTAssertEqual(
                    legacyRun.numberOfMixedTests, modernRun.numberOfMixedTests,
                    "\(fixture): mixed"
                )
            }
        }
    }

    /// Every rule named in the allow-list must be implemented by the masker.
    /// A rule with no implementation would silently mask nothing, leaving the
    /// difference it claims to cover to fail somewhere confusing instead.
    func testEveryAllowListRuleIsImplemented() throws {
        for loss in try allowList().knownLosses {
            XCTAssertTrue(
                KnownLossMasker.implementedRules.contains(loss.rule),
                "Allow-list rule '\(loss.rule)' (\(loss.field)) has no masking "
                    + "implementation in KnownLossMasker."
            )
        }
    }

    /// The assertion the whole exercise exists for: mask exactly the declared
    /// losses out of both renders, and require what remains to be identical.
    ///
    /// This is the strong form. Checking only that declared markers appear and
    /// disappear would prove nothing about the lines nobody declared, and an
    /// undeclared regression would sail straight through.
    func testMaskedRendersAreIdenticalAcrossBackends() throws {
        try requireBothBackends()
        let rules = try allowList().knownLosses.map(\.rule)

        for fixture in Self.fixtures {
            let legacySummary = try summary(fixture, .legacy)
            let legacy = KnownLossMasker.mask(
                normalizeReport(legacySummary.generatedHtmlReport()), rules: rules
            )
            let modern = KnownLossMasker.mask(
                normalizeReport(try summary(fixture, .modern).generatedHtmlReport()),
                rules: rules
            )

            // Non-vacuity: the mask must not have erased the content being
            // compared. Without this, a mask broad enough to delete everything
            // would make the comparison below pass on any two inputs.
            for title in legacySummary.runs.flatMap(\.allTests).map(\.title) {
                XCTAssertTrue(
                    legacy.contains(title),
                    "\(fixture): masking removed test '\(title)' from the "
                        + "comparison. The mask is too broad."
                )
            }

            guard legacy != modern else {
                continue
            }
            let legacyLines = legacy.split(separator: "\n").map(String.init)
            let modernLines = modern.split(separator: "\n").map(String.init)
            let differing = Set(legacyLines).symmetricDifference(Set(modernLines))
            XCTFail(
                """
                \(fixture): \(differing.count) line(s) differ after masking the \
                declared losses. Each is either a parity bug in the modern \
                reader, or an undeclared format loss that needs an allow-list \
                entry with a written justification. First 5:
                \(differing.sorted().prefix(5).joined(separator: "\n"))
                """
            )
        }
    }

    func testAttachmentPayloadsAreByteIdenticalAcrossBackends() throws {
        try requireBothBackends()

        // Keyed by filename and counted, not collected into a Set: a Set
        // collapses duplicates, so a backend that dropped one of two identical
        // screen recordings would still compare equal.
        func payloads(_ summary: Summary) -> [String: [Data]] {
            var byName: [String: [Data]] = [:]
            for attachment in summary.allAttachments {
                guard case let .data(data) = attachment.content else {
                    continue
                }
                byName[attachment.filename, default: []].append(data)
            }
            return byName.mapValues { $0.sorted { $0.count < $1.count } }
        }

        for fixture in Self.fixtures {
            // Rendered inline so the bytes are in hand rather than on disk.
            let legacy = try summaryInline(fixture, .legacy)
            let modern = try summaryInline(fixture, .modern)
            let legacyPayloads = payloads(legacy)
            XCTAssertFalse(
                legacyPayloads.isEmpty,
                "\(fixture): no attachment bytes to compare — the assertion "
                    + "below would pass vacuously"
            )
            XCTAssertEqual(
                legacyPayloads.mapValues(\.count),
                payloads(modern).mapValues(\.count),
                "\(fixture): attachment counts differ between backends"
            )
            XCTAssertEqual(
                legacyPayloads, payloads(modern),
                "\(fixture): attachment bytes differ between backends"
            )
        }
    }

    private func summaryInline(_ resource: String, _ backend: ResultBackend) throws -> Summary {
        let url = try XCTUnwrap(
            Bundle.testBundle.url(forResource: resource, withExtension: "xcresult")
        )
        return Summary(
            resultPaths: [url.path],
            renderingMode: .inline,
            downsizeImagesEnabled: false,
            downsizeScaleFactor: 0.5,
            backend: backend
        )
    }
}
```

- [ ] **Step 5: Run and expect real failures**

```bash
swift test --filter DifferentialTests
```

Expected on the first run: **failures are the point.** Each one is either a
genuine parity bug in the modern reader (fix the reader) or an undeclared
format loss (add an allow-list entry with a written justification). Work
through them one at a time. Do not add a marker to the allow-list without
being able to state which field of the new format is missing.

- [ ] **Step 6: Re-run until green, then run everything**

```bash
swift test 2>&1 | tail -5
```

Expected: the full suite green, 30+ tests.

- [ ] **Step 7: Commit**

```bash
swiftformat . && git add -A
git commit -m "test: assert legacy/modern parity against a declared allow-list"
```

---

## Task 13: CI leg for the modern backend

**Files:**
- Modify: `.github/workflows/test.yml`

- [ ] **Step 1: Add a matrix over the backend**

Replace the `test` job's `runs-on` line with a matrix and thread the backend
through as an environment variable:

```yaml
  test:
    runs-on: macos-latest
    strategy:
      fail-fast: false
      matrix:
        # `auto` is what users get. The forced `modern` leg exercises the path
        # that becomes the only path once Apple removes the legacy commands —
        # without it, the modern reader is only ever covered by the
        # differential tests, and never end to end.
        result_reader: [auto, modern]
    env:
      XCHR_RESULT_READER: ${{ matrix.result_reader }}
```

- [ ] **Step 2: Honour the variable in `Summary`**

The CLI flag stays the primary control; the environment variable is the CI
override, read only when the flag is absent:

```swift
public static func fromEnvironment() -> ResultBackend {
    ProcessInfo.processInfo.environment["XCHR_RESULT_READER"]
        .flatMap(ResultBackend.init(rawValue:)) ?? .auto
}
```

Use it as the default for `Summary.init`'s `backend` parameter, so both
`swift test` and the CLI pick it up.

- [ ] **Step 3: Verify locally**

```bash
XCHR_RESULT_READER=modern swift test 2>&1 | tail -5
XCHR_RESULT_READER=auto swift test 2>&1 | tail -5
```

Expected: green both ways.

**Do not compare the two legs' wall-clock times.** Cross-run CI timings in this
repo have varied 1.8x on identical code.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/test.yml Sources/
git commit -m "ci: run the test suite against the modern reader as well as auto"
```

---

## Task 14: `--json` emits `ParsedResult`

Breaking change, landing in 3.0 with release notes.

**Files:**
- Modify: `Sources/XCTestHTMLReportCore/Classes/ResultReading/ParsedResult.swift`
- Modify: `Sources/XCTestHTMLReportCore/Classes/Models/Summary.swift`
- Modify: `Sources/XCTestHTMLReportCore/Classes/Models/ResultFile.swift`
- Create: `Tests/XCTestHTMLReportTests/JsonReportTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
//
//  JsonReportTests.swift
//

import XCTest
@testable import XCTestHTMLReportCore

final class JsonReportTests: XCTestCase {
    private func json(_ backend: ResultBackend) throws -> [String: Any] {
        let url = try XCTUnwrap(
            Bundle.testBundle.url(forResource: "SanityResults", withExtension: "xcresult")
        )
        let text = Summary(
            resultPaths: [url.path],
            renderingMode: .linking,
            downsizeImagesEnabled: false,
            downsizeScaleFactor: 0.5,
            backend: backend
        ).generatedJsonReport()
        return try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any]
        )
    }

    func testEmitsOurSchemaNotTheLegacyObjectGraph() throws {
        let object = try json(.legacy)
        XCTAssertNotNil(object["runs"])
        // The legacy dump wrapped every scalar in {"_value": ...}. Ours does not.
        XCTAssertFalse(
            String(describing: object).contains("_value"),
            "Output still looks like the legacy object graph"
        )
    }

    func testShapeIsIdenticalAcrossBackends() throws {
        guard XCResultToolClient.legacyCommandsAvailable else {
            throw XCTSkip("Needs both backends")
        }
        XCTAssertEqual(
            Set((try json(.legacy)).keys), Set((try json(.modern)).keys)
        )
    }
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
swift test --filter JsonReportTests
```

Expected: FAIL — output still contains `_value`.

- [ ] **Step 3: Make `ParsedResult` `Encodable` and re-point `--json`**

Add `: Encodable` to every `Parsed*` type and to `ParsedNode`. Replace
`Summary.generatedJsonReport()`:

```swift
/// Emits the parsed model as JSON.
///
/// Before 3.0 this dumped `xcresulttool`'s legacy object graph verbatim. That
/// graph is Apple's internal shape and disappears with the legacy commands, so
/// the output is now our own documented schema — identical on both backends.
public func generatedJsonReport() -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    guard let data = try? encoder.encode(ParsedResult(runs: parsedRuns)),
          let text = String(data: data, encoding: .utf8)
    else {
        return "{}"
    }
    return text
}
```

`Summary` retains the `ParsedResult` it read so this needs no second parse.
Delete `ResultFile.exportJson()` and its `exportRecursiveJson()` call — the
last XCResultKit use outside `LegacyResultReader`.

- [ ] **Step 4: Run tests to verify they pass**

```bash
swift test --filter JsonReportTests && swift test 2>&1 | tail -5
```

Expected: 2 new tests PASS; full suite green.

- [ ] **Step 5: Confirm XCResultKit is confined to one file**

```bash
grep -rln "import XCResultKit" Sources/
```

Expected: exactly
`Sources/XCTestHTMLReportCore/Classes/ResultReading/Legacy/LegacyResultReader.swift`.

- [ ] **Step 6: Commit**

```bash
swiftformat . && git add -A
git commit -m "feat!: emit our own schema from --json instead of the legacy object graph

BREAKING: --json previously dumped xcresulttool's legacy object graph verbatim.
That graph is Apple's internal shape and disappears with the legacy commands,
so --json now emits a documented schema, identical on both backends."
```

---

## Task 15: Documentation

**Files:**
- Modify: `README.md`
- Modify: `docs/superpowers/specs/2026-08-10-xcresulttool-legacy-migration-design.md`

- [ ] **Step 1: Document the flag and the `--json` break in `README.md`**

Add a section covering `--result-reader auto|legacy|modern`, that `auto`
prefers legacy while the toolchain offers it, the `--json` schema change with a
before/after snippet, and the known differences between backends (drawn from
the allow-list, not re-derived).

- [ ] **Step 2: Mark the spec's phases 1-5 done**

Add a short status line at the top of the spec noting which phases landed and
that phase 6 (removing XCResultKit) is deliberately deferred until Apple
removes the legacy commands.

- [ ] **Step 3: Full verification**

```bash
swiftformat --lint --reporter github-actions-log . && echo "FORMAT OK"
swiftlint lint --quiet && echo "LINT OK"
find . -name '*.sh' -not -path './.build/*' -print0 | xargs -0 -r shellcheck && echo "SHELL OK"
swift build -c release 2>&1 | tail -3
swift test 2>&1 | tail -5
XCHR_RESULT_READER=modern swift test 2>&1 | tail -5
```

Expected: every line reports success; both test runs green.

- [ ] **Step 4: Commit**

```bash
git add README.md docs/
git commit -m "docs: document --result-reader and the --json schema change"
```

---

## Follow-up (not this issue)

Open a separate issue for **removing XCResultKit**: delete
`LegacyResultReader`, `ResultBackend.legacy`, the differential test, and the
`Package.swift` dependency. Gate it on Apple actually removing the legacy
commands — while they exist, the differential is the only continuous evidence
that the modern reader is right, and deleting it early throws that away.

---

## Self-Review

**Spec coverage.** Architecture → Tasks 3–9, 11. Renderer-is-defensive and the
fault trap → Tasks 5, 11 (step 4 explicitly). Backend selection → Task 11.
Status mapping → Task 8. Iterations/`.mixed` → Tasks 4, 8, 12. Failure location
→ Tasks 4, 8, allow-list. Attachments and the uuid join → Tasks 9, 10.
Tree shape → Task 8, allow-list. `--json` → Task 14. Reproducibility → Task 1.
Differential → Task 12. CI → Task 13. Dead `getCodeCoverage()` → Task 5 step 3.
Phase 6 → Follow-up. No spec section is unimplemented.

**Placeholders.** None. Every code step carries the code; the one prose-only
step (Task 5 step 1) is a mechanical substitution table with all nine
signatures spelled out.

**Type consistency.** `normalizeReport(_:)` (Tasks 1, 2, 12);
`ResultBackend.resolved()` (Tasks 11, 12, 13); `ParsedIteration.iterationNumber`
(Tasks 3, 4, 8, 5); `ParsedAttachment.filenameExtension` (Tasks 3, 8, 10);
`ModernPayloadStore.exportedFileName(uuid:)` (Tasks 8, 9);
`XCResultToolClient.legacyCommandsAvailable` (Tasks 6, 11, 12, 14). All
consistent.

**Non-vacuity.** Four assertions here would pass trivially on empty input, so
each carries a guard:

- Task 1 asserts the raw renders *do* differ before asserting the normalized
  ones match.
- Task 2 requires all three fixtures and non-empty output, so Task 5's
  `diff -r` cannot compare two partial directories and call them identical.
- Task 12 asserts attachment bytes exist before comparing them, and compares
  them keyed by filename with counts rather than as a `Set<Data>`, which would
  collapse duplicates.
- Task 12's masked comparison asserts every test title survives masking, so a
  mask broad enough to erase the content cannot make the comparison pass.

Verified that all three fixtures carry attachments under `export attachments` —
`TestResults` 9, `RetryResults` 3, `SanityResults` 1 — so the Task 12 guard
passes on real data rather than merely being defensive.

**On the differential's design.** The first draft matched differing lines
against literal marker strings. Checked against `HTMLTemplates.swift`, that does
not work: activity durations render as a bare `(0.00s)` suffix and attachment
names as bare text, with no class to key on. It was replaced with masking —
strip exactly the declared losses from both renders, then require byte
equality — which is both implementable and a strictly stronger claim. Each
masking rule maps 1:1 to an allow-list entry, and a rule named in the JSON with
no implementation fails `testEveryAllowListRuleIsImplemented`.
