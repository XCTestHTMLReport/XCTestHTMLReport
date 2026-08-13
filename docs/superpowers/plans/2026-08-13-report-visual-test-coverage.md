# Report Visual Test Coverage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the rendered report three layers of test coverage — unit tests
on model logic, per-template HTML snapshots, and browser assertions on
computed styles, contrast, dark mode and accessibility — so that #439's
redesign claims are checked by machine rather than by eye.

**Architecture:** One synthetic `ParsedResult` fixture, built in Swift from
the public port types, feeds all three layers. Layers 1 and 2 are XCTest and
need neither a simulator nor an `.xcresult`. Layer 3 is Playwright, confined
to `visual/`, consuming an HTML file that a dump test writes.

**Tech Stack:** Swift 5.5 tools version, macOS 10.15 floor, SwiftPM, XCTest,
Node 20 + Playwright + axe-core (test-only, `visual/` only), GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-08-13-report-visual-test-coverage-design.md`

## Global Constraints

- Swift tools version **5.5**; platform floor **macOS 10.15**. Do not raise either.
- `Sources/XCTestHTMLReportCore/Classes/HTMLTemplates.swift` is excluded from
  SwiftFormat and SwiftLint. **No task in this plan edits it.** Layer 3 reads
  the tokens it emits; it never rewrites them.
- SwiftFormat wraps at 100 columns, `--swiftversion 5.5`,
  `--acronyms ID,URL,UUID`. Run `swiftformat .` before every commit.
- SwiftLint `line_length` warns at 120.
- A pre-commit hook runs via `core.hooksPath` (`.githooks/pre-commit`). Do not
  bypass it.
- Required CI checks on `main` are exactly `shell`, `swift`, `test`. The new
  `visual` job is **not** automatically required — Task 11 covers adding it.
- `zizmor --min-severity low` audits `.github/workflows/`. Pin every action by
  SHA, set `persist-credentials: false` on checkout, and scope `permissions`
  explicitly.
- Fixtures from `./prepareTestResults.sh` are regenerated on every run, so a
  golden keyed to one is impossible. Every golden in this plan is keyed to the
  **synthetic** fixture, whose inputs are constants.
- The `Parsed*` types are `public` structs with `internal` memberwise
  initialisers. Tests reach them through `@testable import XCTestHTMLReportCore`,
  which every existing test file already uses.
- `IdentifierPath` has a `private` stored property, so its memberwise init is
  private. Build paths with `IdentifierPath.root.appending("…")`, never
  `IdentifierPath(path:)`.
- Do not make performance claims. If one is unavoidable it needs a same-runner
  interleaved A/B, never a cross-run CI wall-clock comparison.
- Verification steps that pipe into `tail` report `tail`'s exit status. Run
  `set -o pipefail` before working through this plan.

## File Structure

**Created:**

| path | responsibility |
|---|---|
| `Tests/XCTestHTMLReportTests/Synthetic/StubPayloadProvider.swift` | `PayloadProviding` returning fixed bytes |
| `Tests/XCTestHTMLReportTests/Synthetic/SyntheticResult.swift` | builds the `ParsedResult` tree |
| `Tests/XCTestHTMLReportTests/TestScreenshotFlowTests.swift` | Layer 1 unit tests |
| `Tests/XCTestHTMLReportTests/SnapshotSupport.swift` | golden compare + refresh helper |
| `Tests/XCTestHTMLReportTests/TemplateSnapshotTests.swift` | Layer 2 snapshots |
| `Tests/XCTestHTMLReportTests/Snapshots/*.html` | committed goldens |
| `Tests/XCTestHTMLReportTests/VisualFixtureDumpTests.swift` | writes HTML for Layer 3 |
| `visual/package.json`, `visual/package-lock.json` | pinned Node deps |
| `visual/playwright.config.ts` | Playwright config |
| `visual/tests/tokens.spec.ts` | token resolution + contrast + dark mode |
| `visual/tests/a11y.spec.ts` | axe-core |
| `visual/tests/behaviour.spec.ts` | filters, keyboard, preview pane |
| `.github/workflows/visual.yml` | two-job CI wiring |

**Modified:**

| path | change |
|---|---|
| `Sources/XCTestHTMLReportCore/Classes/Models/Summary.swift` | add `init(parsedRuns:…)` |
| `Sources/XCTestHTMLReportCore/Classes/Models/TestScreenshotFlow.swift` | honour `tailCount` |
| `.gitignore` | ignore `visual/node_modules`, `visual/test-results` |

---

## Phase 1 — Swift foundation

### Task 1: Stub payload provider and the `tailCount` defect

`TestScreenshotFlow.init?(activities:tailCount:)` declares `tailCount _: Int = 3`
— the parameter is discarded — and hardcodes `.suffix(3)`. Its only caller,
`Iteration.swift:26`, never passes it, so nothing has noticed. This task builds
the minimum fixture machinery needed to prove it, then fixes it.

**Files:**
- Create: `Tests/XCTestHTMLReportTests/Synthetic/StubPayloadProvider.swift`
- Create: `Tests/XCTestHTMLReportTests/Synthetic/SyntheticResult.swift`
- Create: `Tests/XCTestHTMLReportTests/TestScreenshotFlowTests.swift`
- Modify: `Sources/XCTestHTMLReportCore/Classes/Models/TestScreenshotFlow.swift:12,31`

**Interfaces:**
- Produces: `StubPayloadProvider(url:exports:)`;
  `StubPayloadProvider.onePixelPNG: Data`;
  `SyntheticResult.pngAttachment(reference:) -> ParsedAttachment`;
  `SyntheticResult.activity(title:attachments:subActivities:) -> ParsedActivity`;
  `SyntheticResult.activities(_ parsed: [ParsedActivity]) -> [Activity]`

- [ ] **Step 1: Write the stub payload provider**

```swift
//
//  StubPayloadProvider.swift
//
//  A PayloadProviding whose bytes are constants, so a render driven by it is
//  identical on every machine and every run. This is what lets Layer 2 commit
//  goldens at all: the generated .xcresult fixtures cannot support one.
//

import Foundation
@testable import XCTestHTMLReportCore

struct StubPayloadProvider: PayloadProviding {
    /// A 1x1 opaque PNG, base64 rather than generated so the bytes never
    /// depend on the encoder available on the machine running the test.
    static let onePixelPNG = Data(
        base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ"
            + "AAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
    )!

    static let plainText = Data("synthetic attachment body\n".utf8)

    let url: URL
    let exports: [String: Data]

    init(url: URL = URL(fileURLWithPath: "/synthetic.xcresult"), exports: [String: Data]) {
        self.url = url
        self.exports = exports
    }

    func exportPayload(reference: String, fileName: String?) -> URL? {
        guard exports[reference] != nil else { return nil }
        return URL(fileURLWithPath: fileName ?? reference, relativeTo: url)
    }

    func exportPayloadData(reference: String) -> Data? {
        exports[reference]
    }
}
```

- [ ] **Step 2: Write the minimal synthetic builders**

```swift
//
//  SyntheticResult.swift
//
//  Builds a ParsedResult tree from constants. Task 2 extends this to the full
//  tree; Task 1 needs only enough to construct Activity values.
//

import Foundation
@testable import XCTestHTMLReportCore

enum SyntheticResult {
    static let pngReference = "payload-png"
    static let textReference = "payload-text"

    static var payloads: StubPayloadProvider {
        StubPayloadProvider(exports: [
            pngReference: StubPayloadProvider.onePixelPNG,
            textReference: StubPayloadProvider.plainText,
        ])
    }

    static func pngAttachment(reference: String = pngReference) -> ParsedAttachment {
        ParsedAttachment(
            name: "Screenshot",
            filename: "screenshot.png",
            filenameExtension: "png",
            payloadReference: reference
        )
    }

    static func activity(
        title: String,
        attachments: [ParsedAttachment] = [],
        subActivities: [ParsedActivity] = []
    ) -> ParsedActivity {
        ParsedActivity(
            title: title,
            isFailure: false,
            start: Date(timeIntervalSince1970: 0),
            attachments: attachments,
            subActivities: subActivities
        )
    }

    /// Renders parsed activities into model `Activity` values, which is what
    /// `TestScreenshotFlow` consumes.
    static func activities(_ parsed: [ParsedActivity]) -> [Activity] {
        let payloads = payloads
        return parsed.enumerated().map { index, item in
            Activity(
                activity: item,
                identifierPath: IdentifierPath.root.appending("activity-\(index)"),
                file: payloads,
                renderingMode: .linking,
                downsizeImagesEnabled: false,
                downsizeScaleFactor: 0.5
            )
        }
    }
}
```

- [ ] **Step 3: Write the failing test**

```swift
//
//  TestScreenshotFlowTests.swift
//

import XCTest
@testable import XCTestHTMLReportCore

final class TestScreenshotFlowTests: XCTestCase {
    /// Five activities, each carrying one screenshot.
    private func fiveScreenshotActivities() -> [Activity] {
        SyntheticResult.activities(
            (1...5).map { index in
                SyntheticResult.activity(
                    title: "Activity \(index)",
                    attachments: [SyntheticResult.pngAttachment()]
                )
            }
        )
    }

    func testTailCountIsHonoured() throws {
        let flow = try XCTUnwrap(
            TestScreenshotFlow(activities: fiveScreenshotActivities(), tailCount: 5)
        )
        XCTAssertEqual(
            flow.screenshotsTail.count, 5,
            "tailCount: 5 must yield five tail screenshots, not the hardcoded 3"
        )
    }

    func testTailCountDefaultsToThree() throws {
        let flow = try XCTUnwrap(
            TestScreenshotFlow(activities: fiveScreenshotActivities())
        )
        XCTAssertEqual(flow.screenshotsTail.count, 3)
    }

    func testTailAndFlowUseDistinctClassNames() throws {
        let flow = try XCTUnwrap(
            TestScreenshotFlow(activities: fiveScreenshotActivities())
        )
        XCTAssertEqual(Set(flow.screenshots.map(\.className)), ["screenshot-flow"])
        XCTAssertEqual(Set(flow.screenshotsTail.map(\.className)), ["screenshot-tail"])
    }

    func testNilWhenNoScreenshots() {
        let activities = SyntheticResult.activities([
            SyntheticResult.activity(title: "No attachments"),
        ])
        XCTAssertNil(TestScreenshotFlow(activities: activities))
    }
}
```

- [ ] **Step 4: Run the test to verify it fails**

Run: `set -o pipefail; swift test --filter TestScreenshotFlowTests 2>&1 | tail -20`
Expected: `testTailCountIsHonoured` FAILS with `XCTAssertEqual failed: ("3") is not equal to ("5")`. The other three PASS.

If `testTailCountIsHonoured` passes, stop — the defect was fixed elsewhere and this plan needs revisiting.

- [ ] **Step 5: Fix the source**

In `Sources/XCTestHTMLReportCore/Classes/Models/TestScreenshotFlow.swift`, bind
the parameter and use it:

```swift
    init?(activities: [Activity]?, tailCount: Int = 3) {
```

and replace the hardcoded suffix:

```swift
            .suffix(tailCount)
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `set -o pipefail; swift test --filter TestScreenshotFlowTests 2>&1 | tail -20`
Expected: 4 tests, all PASS.

- [ ] **Step 7: Run the full suite for regressions**

Run: `set -o pipefail; swift test 2>&1 | tail -20`
Expected: no new failures. `Iteration.swift:26` passes no `tailCount`, so the
default preserves existing behaviour and every golden-free comparison is
unaffected.

- [ ] **Step 8: Commit**

```bash
swiftformat .
git add Tests/XCTestHTMLReportTests/Synthetic Tests/XCTestHTMLReportTests/TestScreenshotFlowTests.swift Sources/XCTestHTMLReportCore/Classes/Models/TestScreenshotFlow.swift
git commit -m "TestScreenshotFlow honours tailCount instead of hardcoding 3"
```

---

### Task 2: The full synthetic tree

**Files:**
- Modify: `Tests/XCTestHTMLReportTests/Synthetic/SyntheticResult.swift`
- Test: `Tests/XCTestHTMLReportTests/SyntheticResultTests.swift` (create)

**Interfaces:**
- Consumes: everything Task 1 produced.
- Produces: `SyntheticResult.parsedResult: ParsedResult`,
  `SyntheticResult.parsedRun: ParsedRun`.

- [ ] **Step 1: Write the failing test**

```swift
//
//  SyntheticResultTests.swift
//
//  The fixture is the shared input to every layer below it, so its shape is
//  asserted rather than assumed. A fixture that silently stops covering
//  `expectedFailure` would leave a whole rendered state untested with no
//  failing test to show for it.
//

import XCTest
@testable import XCTestHTMLReportCore

final class SyntheticResultTests: XCTestCase {
    func testCoversEveryRenderedStatus() {
        let statuses = SyntheticResult.parsedResult.runs
            .flatMap(\.testables)
            .flatMap(\.groups)
            .flatMap { group -> [ParsedTestCase] in
                group.children.compactMap {
                    if case let .testCase(testCase) = $0 { return testCase }
                    return nil
                }
            }
            .flatMap(\.iterations)
            .map(\.status)

        XCTAssertEqual(
            Set(statuses),
            [.passed, .failed, .skipped, .expectedFailure],
            "Every status the renderer draws differently must appear"
        )
    }

    func testCoversRetries() {
        let iterationCounts = SyntheticResult.parsedResult.runs
            .flatMap(\.testables)
            .flatMap(\.groups)
            .flatMap { group -> [ParsedTestCase] in
                group.children.compactMap {
                    if case let .testCase(testCase) = $0 { return testCase }
                    return nil
                }
            }
            .map(\.iterations.count)

        XCTAssertTrue(
            iterationCounts.contains { $0 > 1 },
            "At least one test case must have repetitions"
        )
    }

    func testCoversHostileAttachmentFilename() {
        let filenames = SyntheticResult.parsedResult.runs
            .flatMap(\.testables)
            .flatMap(\.groups)
            .flatMap { group -> [ParsedTestCase] in
                group.children.compactMap {
                    if case let .testCase(testCase) = $0 { return testCase }
                    return nil
                }
            }
            .flatMap(\.iterations)
            .flatMap(\.activities)
            .flatMap(\.attachments)
            .compactMap(\.filename)

        XCTAssertTrue(
            filenames.contains { $0.contains("\"") && $0.contains("<") },
            "A filename with quotes and angle brackets must be present — it is "
                + "the escaping path the real fixture covers"
        )
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `set -o pipefail; swift test --filter SyntheticResultTests 2>&1 | tail -20`
Expected: FAIL to compile with `type 'SyntheticResult' has no member 'parsedResult'`.

- [ ] **Step 3: Extend the fixture**

Append to `SyntheticResult`:

```swift
    static func textAttachment() -> ParsedAttachment {
        ParsedAttachment(
            name: "Log",
            filename: "FileName with DoubleQuote\"SingleQuote'LessThan<GreaterThan>Ampersand&.txt",
            filenameExtension: "txt",
            payloadReference: textReference
        )
    }

    static func iteration(
        number: Int?,
        status: ParsedStatus,
        activities: [ParsedActivity]
    ) -> ParsedIteration {
        ParsedIteration(
            iterationNumber: number,
            status: status,
            duration: 1.5,
            activities: activities
        )
    }

    static func testCase(
        name: String,
        iterations: [ParsedIteration]
    ) -> ParsedTestCase {
        ParsedTestCase(
            name: name,
            identifier: "Synthetic/\(name)",
            arguments: [],
            iterations: iterations
        )
    }

    static var parsedRun: ParsedRun {
        let standardActivities = [
            activity(title: "Start Test", attachments: []),
            activity(
                title: "Attachments",
                attachments: [pngAttachment(), textAttachment()]
            ),
            activity(
                title: "Nested",
                subActivities: [activity(title: "Inner step")]
            ),
        ]

        let failureActivity = ParsedActivity(
            title: "Synthetic.swift:42: assertion failed",
            isFailure: true,
            start: Date(timeIntervalSince1970: 1),
            attachments: [pngAttachment()],
            subActivities: []
        )

        let group = ParsedGroup(
            name: "SyntheticSuite",
            identifier: "SyntheticSuite",
            duration: 6,
            children: [
                .testCase(testCase(
                    name: "testPasses()",
                    iterations: [iteration(number: nil, status: .passed, activities: standardActivities)]
                )),
                .testCase(testCase(
                    name: "testFails()",
                    iterations: [iteration(
                        number: nil,
                        status: .failed,
                        activities: standardActivities + [failureActivity]
                    )]
                )),
                .testCase(testCase(
                    name: "testSkips()",
                    iterations: [iteration(number: nil, status: .skipped, activities: [])]
                )),
                .testCase(testCase(
                    name: "testExpectedlyFails()",
                    iterations: [iteration(
                        number: nil,
                        status: .expectedFailure,
                        activities: [failureActivity]
                    )]
                )),
                .testCase(testCase(
                    name: "testRetries()",
                    iterations: [
                        iteration(number: 1, status: .failed, activities: [failureActivity]),
                        iteration(number: 2, status: .passed, activities: standardActivities),
                    ]
                )),
            ]
        )

        return ParsedRun(
            destination: ParsedDestination(
                displayName: "Synthetic Device",
                deviceIdentifier: "00000000-0000-0000-0000-000000000000",
                modelName: "Synthetic Model",
                operatingSystemVersion: "1.0"
            ),
            logReference: nil,
            testables: [ParsedTestable(targetName: "SyntheticTests", groups: [group])]
        )
    }

    static var parsedResult: ParsedResult {
        ParsedResult(runs: [parsedRun])
    }
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `set -o pipefail; swift test --filter SyntheticResultTests 2>&1 | tail -20`
Expected: 3 tests, all PASS.

- [ ] **Step 5: Commit**

```bash
swiftformat .
git add Tests/XCTestHTMLReportTests/Synthetic/SyntheticResult.swift Tests/XCTestHTMLReportTests/SyntheticResultTests.swift
git commit -m "Synthetic ParsedResult fixture covering every rendered state"
```

---

### Task 3: The `Summary` seam

`Summary`'s only public initialiser takes `resultPaths: [String]` and reads
them internally. Without a way to hand it pre-parsed runs, snapshots reach 13
of the 14 `HTMLTemplates` members but never `index` — the full page, and the
only place the stylesheet and token layer appear.

**Files:**
- Modify: `Sources/XCTestHTMLReportCore/Classes/Models/Summary.swift`
- Test: `Tests/XCTestHTMLReportTests/SummarySeamTests.swift` (create)

**Interfaces:**
- Consumes: `SyntheticResult.parsedRun`.
- Produces: `Summary(parsedRuns:renderingMode:downsizeImagesEnabled:downsizeScaleFactor:faultCollector:)`.

- [ ] **Step 1: Write the failing test**

```swift
//
//  SummarySeamTests.swift
//

import XCTest
@testable import XCTestHTMLReportCore

final class SummarySeamTests: XCTestCase {
    private func summary() -> Summary {
        Summary(
            parsedRuns: [SyntheticResult.parsedRun],
            renderingMode: .linking,
            downsizeImagesEnabled: false,
            downsizeScaleFactor: 0.5
        )
    }

    func testRendersAFullPageWithoutAnXcresult() {
        let html = summary().generatedHtmlReport()
        XCTAssertTrue(html.hasPrefix("<!doctype html>"), "must render the index template")
        XCTAssertTrue(html.contains("SyntheticSuite"), "must render the fixture's group")
        XCTAssertTrue(html.contains(":root"), "must carry the token layer")
    }

    func testRendersNoFaults() {
        XCTAssertTrue(
            summary().faults.isEmpty,
            "A complete synthetic tree must not degrade the report"
        )
    }

    func testIsDeterministic() {
        XCTAssertEqual(
            summary().generatedHtmlReport(),
            summary().generatedHtmlReport(),
            "Two renders of one fixture must agree byte for byte"
        )
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `set -o pipefail; swift test --filter SummarySeamTests 2>&1 | tail -20`
Expected: FAIL to compile — `extra argument 'parsedRuns' in call`.

- [ ] **Step 3: Add the initialiser**

`Summary` declares exactly four stored properties — `runs`, `parsedRuns`,
`faultCollector`, `bundleNames` — so the initialiser assigns those four and
nothing else. In `Summary.swift`, alongside the existing
`public init(resultPaths:…)`, add:

```swift
    /// Builds a summary from already-parsed runs, bypassing result reading.
    ///
    /// #391 made `ParsedResult` the contract between reading and rendering;
    /// this injects at that boundary rather than bolting a back door onto an
    /// unrelated type. Tests use it to render from constants, which is what
    /// makes committed golden files possible at all — renders driven by the
    /// generated .xcresult fixtures cannot support one, because the fixtures
    /// are regenerated on every run.
    ///
    /// Internal, not public, because `PayloadProviding` is internal.
    /// `@testable import` reaches it; library consumers keep the path-based
    /// initialiser.
    init(
        parsedRuns: [ParsedRun],
        payloads: PayloadProviding,
        renderingMode: RenderingMode,
        downsizeImagesEnabled: Bool,
        downsizeScaleFactor: CGFloat,
        faultCollector: FaultCollector = FaultCollector(),
        bundleNames: [String] = ["Synthetic"]
    ) {
        self.faultCollector = faultCollector
        self.bundleNames = bundleNames
        self.parsedRuns = parsedRuns
        runs = parsedRuns.enumerated().compactMap { index, run in
            Run(
                run: run,
                identifierPath: IdentifierPath.root.appending("run-\(index)"),
                file: payloads,
                renderingMode: renderingMode,
                downsizeImagesEnabled: downsizeImagesEnabled,
                downsizeScaleFactor: downsizeScaleFactor
            )
        }
    }
```

Two things to be aware of:

- `Run.init?` is failable and `compactMap` drops a `nil` silently, which would
  leave `runs` empty and still render a page. `testRendersAFullPageWithoutAnXcresult`
  asserts on `SyntheticSuite` appearing in the output precisely so an empty
  `runs` cannot pass.
- The identifier path shape here (`run-0`, `run-1`) need not match what the
  real readers build. Identifiers are digests of the structural path (#430), so
  synthetic identifiers differ from real ones by design; all the goldens need
  is that they are *deterministic*, which a fixed path makes them.

- [ ] **Step 4: Run the test to verify it passes**

Run: `set -o pipefail; swift test --filter SummarySeamTests 2>&1 | tail -20`
Expected: 3 tests, all PASS.

- [ ] **Step 5: Run the full suite**

Run: `set -o pipefail; swift test 2>&1 | tail -20`
Expected: no new failures. The existing path-based initialiser is untouched.

- [ ] **Step 6: Commit**

```bash
swiftformat .
git add Sources/XCTestHTMLReportCore/Classes/Models/Summary.swift Tests/XCTestHTMLReportTests/SummarySeamTests.swift
git commit -m "Summary initialiser taking pre-parsed runs, for fixture-free rendering"
```

---

## Phase 2 — Snapshots

### Task 4: Snapshot harness and the first golden

**Files:**
- Create: `Tests/XCTestHTMLReportTests/SnapshotSupport.swift`
- Create: `Tests/XCTestHTMLReportTests/TemplateSnapshotTests.swift`
- Create: `Tests/XCTestHTMLReportTests/Snapshots/index.html`

**Interfaces:**
- Produces: `assertSnapshot(_ actual: String, named: String, file:line:)`.

- [ ] **Step 1: Write the harness**

```swift
//
//  SnapshotSupport.swift
//
//  Golden-file comparison for renders driven by the synthetic fixture.
//
//  Goldens are possible here and impossible for the generated .xcresult
//  fixtures for one reason: the synthetic fixture's inputs are constants, so
//  the render changes only when the code does. Refresh with
//  XCHR_UPDATE_SNAPSHOTS=1, which mirrors the XCHR_BASELINE_DIR idiom rather
//  than inventing a second convention.
//

import XCTest

/// Directory holding committed goldens. Derived from this file's path so it
/// resolves the same whether run from Xcode or `swift test`.
private let snapshotDirectory = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("Snapshots")

func assertSnapshot(
    _ actual: String,
    named name: String,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let url = snapshotDirectory.appendingPathComponent("\(name).html")

    if ProcessInfo.processInfo.environment["XCHR_UPDATE_SNAPSHOTS"] == "1" {
        do {
            try FileManager.default.createDirectory(
                at: snapshotDirectory, withIntermediateDirectories: true
            )
            try actual.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            XCTFail("Could not write golden \(name): \(error)", file: file, line: line)
        }
        return
    }

    guard let expected = try? String(contentsOf: url, encoding: .utf8) else {
        XCTFail(
            "Missing golden \(name).html. Create it with "
                + "XCHR_UPDATE_SNAPSHOTS=1 swift test, then review the diff before committing.",
            file: file, line: line
        )
        return
    }

    if actual != expected {
        // Report the first differing line rather than dumping the whole file:
        // index.html is tens of thousands of lines and an unabridged diff in
        // the test log is unreadable.
        let actualLines = actual.components(separatedBy: "\n")
        let expectedLines = expected.components(separatedBy: "\n")
        let firstDifference = zip(actualLines, expectedLines)
            .enumerated()
            .first { $0.element.0 != $0.element.1 }

        let detail: String
        if let difference = firstDifference {
            detail = """
            First difference at line \(difference.offset + 1):
              expected: \(difference.element.1)
                actual: \(difference.element.0)
            """
        } else {
            detail = "Line counts differ: expected \(expectedLines.count), got \(actualLines.count)"
        }

        XCTFail(
            """
            Snapshot \(name) changed.
            \(detail)
            If intended, refresh with: XCHR_UPDATE_SNAPSHOTS=1 swift test
            """,
            file: file, line: line
        )
    }
}
```

- [ ] **Step 2: Write the first snapshot test**

```swift
//
//  TemplateSnapshotTests.swift
//

import XCTest
@testable import XCTestHTMLReportCore

final class TemplateSnapshotTests: XCTestCase {
    private func summary(renderingMode: Summary.RenderingMode = .linking) -> Summary {
        Summary(
            parsedRuns: [SyntheticResult.parsedRun],
            payloads: SyntheticResult.payloads,
            renderingMode: renderingMode,
            downsizeImagesEnabled: false,
            downsizeScaleFactor: 0.5
        )
    }

    func testIndexPage() {
        assertSnapshot(summary().generatedHtmlReport(), named: "index")
    }
}
```

- [ ] **Step 3: Run to verify it fails**

Run: `set -o pipefail; swift test --filter TemplateSnapshotTests 2>&1 | tail -20`
Expected: FAIL with `Missing golden index.html`.

- [ ] **Step 4: Generate and review the golden**

```bash
XCHR_UPDATE_SNAPSHOTS=1 swift test --filter TemplateSnapshotTests
wc -l Tests/XCTestHTMLReportTests/Snapshots/index.html
grep -c "screenshot-tail" Tests/XCTestHTMLReportTests/Snapshots/index.html
```

Read the generated file before committing it. It must contain `SyntheticSuite`,
the five test names, and a `:root` block. A golden committed unread is a golden
that pins a bug.

- [ ] **Step 5: Run to verify it passes**

Run: `set -o pipefail; swift test --filter TemplateSnapshotTests 2>&1 | tail -20`
Expected: PASS.

- [ ] **Step 6: Verify the golden actually detects change**

Temporarily edit `SyntheticResult.parsedRun` to rename `SyntheticSuite` to
`Changed`, re-run, confirm FAIL, then revert.

Run: `set -o pipefail; swift test --filter TemplateSnapshotTests 2>&1 | tail -10`
Expected: FAIL naming the first differing line. Revert before committing.

- [ ] **Step 7: Commit**

```bash
swiftformat .
git add Tests/XCTestHTMLReportTests/SnapshotSupport.swift Tests/XCTestHTMLReportTests/TemplateSnapshotTests.swift Tests/XCTestHTMLReportTests/Snapshots
git commit -m "Snapshot harness and the index golden, keyed to the synthetic fixture"
```

---

### Task 5: Remaining template goldens

**Files:**
- Modify: `Tests/XCTestHTMLReportTests/TemplateSnapshotTests.swift`
- Create: `Tests/XCTestHTMLReportTests/Snapshots/index-inline.html`

- [ ] **Step 1: Add the inline-mode case**

```swift
    /// Inline mode base64s every attachment. Covered separately because it is
    /// a different escaping path, and because `--rendering-mode` is the flag
    /// the published demo and the PR artifact both depend on.
    func testIndexPageInlineMode() {
        assertSnapshot(summary(renderingMode: .inline).generatedHtmlReport(), named: "index-inline")
    }
```

- [ ] **Step 2: Generate and review**

```bash
XCHR_UPDATE_SNAPSHOTS=1 swift test --filter TemplateSnapshotTests
grep -oE 'data:[a-z]+/[a-z0-9.+-]+;base64' Tests/XCTestHTMLReportTests/Snapshots/index-inline.html | sort | uniq -c
```

Expected: at least one `data:image/png;base64` and one `data:text/plain;base64`.
If either is missing, the fixture is not exercising inline attachment
rendering and Step 1 of Task 2 needs revisiting.

- [ ] **Step 3: Run to verify both pass**

Run: `set -o pipefail; swift test --filter TemplateSnapshotTests 2>&1 | tail -20`
Expected: 2 tests, both PASS.

- [ ] **Step 4: Verify the layer needs no fixtures**

The point of the synthetic fixture is that Layers 1 and 2 do not depend on a
simulator or an `.xcresult`. Prove it rather than assuming it:

```bash
mv Tests/XCTestHTMLReportTests/Resources /tmp/resources-parked
set -o pipefail
swift test --filter "TemplateSnapshotTests|TestScreenshotFlowTests|SyntheticResultTests|SummarySeamTests" 2>&1 | tail -20
mv /tmp/resources-parked Tests/XCTestHTMLReportTests/Resources
```

Expected: all four suites PASS with the fixture directory absent. Restore the
directory immediately — the other suites need it.

- [ ] **Step 5: Commit**

```bash
git add Tests/XCTestHTMLReportTests/TemplateSnapshotTests.swift Tests/XCTestHTMLReportTests/Snapshots
git commit -m "Inline-mode golden alongside the linking-mode one"
```

---

## Phase 3 — Browser

### Task 6: Dump the rendered fixture for Playwright

**Files:**
- Create: `Tests/XCTestHTMLReportTests/VisualFixtureDumpTests.swift`

**Interfaces:**
- Produces: `$XCHR_VISUAL_DIR/report.html` and `$XCHR_VISUAL_DIR/report-inline.html`.

- [ ] **Step 1: Write the dump test**

```swift
//
//  VisualFixtureDumpTests.swift
//
//  Writes the synthetic render to $XCHR_VISUAL_DIR for the Playwright suite.
//  Skipped unless the variable is set, exactly like BaselineCaptureTests, so a
//  normal `swift test` neither writes files nor slows down.
//

import XCTest
@testable import XCTestHTMLReportCore

final class VisualFixtureDumpTests: XCTestCase {
    func testDumpSyntheticRender() throws {
        guard let dir = ProcessInfo.processInfo.environment["XCHR_VISUAL_DIR"] else {
            throw XCTSkip("Set XCHR_VISUAL_DIR to dump the visual fixture")
        }
        try FileManager.default.createDirectory(
            atPath: dir, withIntermediateDirectories: true
        )

        for (mode, name) in [(Summary.RenderingMode.linking, "report"),
                             (Summary.RenderingMode.inline, "report-inline")] {
            let html = Summary(
                parsedRuns: [SyntheticResult.parsedRun],
                payloads: SyntheticResult.payloads,
                renderingMode: mode,
                downsizeImagesEnabled: false,
                downsizeScaleFactor: 0.5
            ).generatedHtmlReport()

            let path = "\(dir)/\(name).html"
            try html.write(toFile: path, atomically: true, encoding: .utf8)

            // A zero-byte dump would let the Playwright suite pass vacuously.
            let written = try XCTUnwrap(
                FileManager.default.contents(atPath: path),
                "Dump produced no file at \(path)"
            )
            XCTAssertGreaterThan(written.count, 1000, "\(name).html is suspiciously small")
        }
    }
}
```

- [ ] **Step 2: Run it and confirm the output**

```bash
set -o pipefail
XCHR_VISUAL_DIR="$PWD/visual/fixtures" swift test --filter VisualFixtureDumpTests 2>&1 | tail -10
ls -l visual/fixtures/
```

Expected: PASS; two files present, both well over 1 KB.

- [ ] **Step 3: Confirm it skips by default**

Run: `set -o pipefail; swift test --filter VisualFixtureDumpTests 2>&1 | tail -5`
Expected: skipped, no files written.

- [ ] **Step 4: Commit**

```bash
swiftformat .
git add Tests/XCTestHTMLReportTests/VisualFixtureDumpTests.swift
git commit -m "Dump the synthetic render for the browser suite"
```

---

### Task 7: Playwright scaffold and token resolution

**Files:**
- Create: `visual/package.json`, `visual/playwright.config.ts`, `visual/tests/tokens.spec.ts`
- Modify: `.gitignore`

- [ ] **Step 1: Ignore Node artifacts**

Append to `.gitignore`:

```
# Browser test layer (see .github/workflows/visual.yml).
visual/node_modules
visual/test-results
visual/playwright-report
visual/fixtures
```

- [ ] **Step 2: Create the package manifest**

`visual/package.json`:

```json
{
  "name": "xchtmlreport-visual",
  "private": true,
  "description": "Browser assertions over a rendered report. Not published.",
  "scripts": {
    "test": "playwright test"
  },
  "devDependencies": {
    "@playwright/test": "1.56.1",
    "@axe-core/playwright": "4.10.2"
  }
}
```

Versions are pinned exactly, with no `^`, so the browser layer cannot drift
under a rerun.

- [ ] **Step 3: Create the Playwright config**

`visual/playwright.config.ts`:

```ts
import { defineConfig } from '@playwright/test';

// The suite reads a file the Swift dump test wrote; there is no server and no
// .xcresult involved. Chromium only: these assertions are about token values
// and computed styles, which are engine-independent, so a second engine would
// triple the runtime and assert the same numbers.
export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: 0,
  reporter: process.env.CI ? [['github'], ['html', { open: 'never' }]] : 'list',
  use: {
    screenshot: 'only-on-failure',
  },
  projects: [{ name: 'chromium', use: { browserName: 'chromium' } }],
});
```

`retries: 0` is deliberate. Every assertion here is deterministic; a retry
would hide a real flake rather than reveal it.

- [ ] **Step 4: Write the token resolution spec**

`visual/tests/tokens.spec.ts`:

```ts
import { test, expect } from '@playwright/test';
import { pathToFileURL } from 'node:url';
import { resolve } from 'node:path';

const reportURL = pathToFileURL(resolve(__dirname, '../fixtures/report.html')).href;

/** Every custom property declared on :root, read from the live stylesheet. */
async function declaredTokens(page): Promise<string[]> {
  return page.evaluate(() => {
    const names = new Set<string>();
    for (const sheet of Array.from(document.styleSheets)) {
      for (const rule of Array.from(sheet.cssRules)) {
        if (!(rule instanceof CSSStyleRule)) continue;
        if (!rule.selectorText.split(',').some((s) => s.trim() === ':root')) continue;
        for (const prop of Array.from(rule.style)) {
          if (prop.startsWith('--')) names.add(prop);
        }
      }
    }
    return Array.from(names);
  });
}

test('every declared token resolves to a non-empty value', async ({ page }) => {
  await page.goto(reportURL);
  const tokens = await declaredTokens(page);

  expect(tokens.length, 'the stylesheet must declare custom properties').toBeGreaterThan(0);

  for (const token of tokens) {
    const value = await page.evaluate(
      (name) => getComputedStyle(document.documentElement).getPropertyValue(name).trim(),
      token,
    );
    expect(value, `${token} resolves to nothing`).not.toBe('');
  }
});

test('no rule references an undeclared token', async ({ page }) => {
  await page.goto(reportURL);
  const declared = new Set(await declaredTokens(page));

  const referenced: string[] = await page.evaluate(() => {
    const names = new Set<string>();
    for (const sheet of Array.from(document.styleSheets)) {
      for (const rule of Array.from(sheet.cssRules)) {
        if (!(rule instanceof CSSStyleRule)) continue;
        for (const prop of Array.from(rule.style)) {
          const value = rule.style.getPropertyValue(prop);
          for (const match of value.matchAll(/var\(\s*(--[\w-]+)/g)) {
            names.add(match[1]);
          }
        }
      }
    }
    return Array.from(names);
  });

  const undeclared = referenced.filter((name) => !declared.has(name));
  expect(undeclared, `referenced but never declared: ${undeclared.join(', ')}`).toEqual([]);
});
```

- [ ] **Step 5: Install and run**

```bash
cd visual
npm install
npx playwright install --with-deps chromium
npx playwright test tests/tokens.spec.ts
```

Expected: 2 tests PASS. The fixture must already exist from Task 6; if it does
not, re-run that dump first.

- [ ] **Step 6: Verify the assertions actually bite**

In `HTMLTemplates.swift`, temporarily change one `var(--color-text-primary)`
reference to `var(--color-text-nonexistent)`, re-dump, re-run.

```bash
cd .. && XCHR_VISUAL_DIR="$PWD/visual/fixtures" swift test --filter VisualFixtureDumpTests
cd visual && npx playwright test tests/tokens.spec.ts
```

Expected: `no rule references an undeclared token` FAILS naming
`--color-text-nonexistent`. **Revert the template edit before committing** —
the global constraints forbid leaving `HTMLTemplates.swift` modified.

- [ ] **Step 7: Commit**

```bash
cd ..
git add .gitignore visual/package.json visual/package-lock.json visual/playwright.config.ts visual/tests/tokens.spec.ts
git commit -m "Playwright scaffold and token-resolution assertions"
```

---

### Task 8: Contrast and dark mode

**Files:**
- Modify: `visual/tests/tokens.spec.ts`

- [ ] **Step 1: Add the contrast helper and assertions**

Append to `visual/tests/tokens.spec.ts`:

```ts
/** WCAG 2.1 relative luminance. */
function luminance(rgb: [number, number, number]): number {
  const [r, g, b] = rgb.map((channel) => {
    const c = channel / 255;
    return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
  });
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

function contrastRatio(a: [number, number, number], b: [number, number, number]): number {
  const [light, dark] = [luminance(a), luminance(b)].sort((x, y) => y - x);
  return (light + 0.05) / (dark + 0.05);
}

/**
 * Resolved foreground/background pairs for every element that carries text.
 * Discovered from the live cascade rather than a hand-written matrix: a fixed
 * list stops covering a pairing the moment the redesign introduces one.
 */
async function textPairs(page) {
  return page.evaluate(() => {
    const parse = (value: string): [number, number, number] | null => {
      const match = value.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)/);
      return match ? [Number(match[1]), Number(match[2]), Number(match[3])] : null;
    };
    const effectiveBackground = (element: Element): [number, number, number] => {
      let node: Element | null = element;
      while (node) {
        const bg = parse(getComputedStyle(node).backgroundColor);
        const alpha = getComputedStyle(node).backgroundColor.match(/rgba\([^)]*,\s*0\)/);
        if (bg && !alpha) return bg;
        node = node.parentElement;
      }
      return [255, 255, 255];
    };

    const results: { selector: string; fg: number[]; bg: number[]; size: number; bold: boolean }[] = [];
    for (const element of Array.from(document.querySelectorAll('body *'))) {
      const text = Array.from(element.childNodes)
        .filter((n) => n.nodeType === Node.TEXT_NODE)
        .map((n) => n.textContent?.trim() ?? '')
        .join('');
      if (!text) continue;
      const style = getComputedStyle(element);
      if (style.visibility === 'hidden' || style.display === 'none') continue;
      const fg = parse(style.color);
      if (!fg) continue;
      results.push({
        selector: element.tagName.toLowerCase() + (element.className ? `.${element.className}` : ''),
        fg,
        bg: effectiveBackground(element),
        size: parseFloat(style.fontSize),
        bold: Number(style.fontWeight) >= 700,
      });
    }
    return results;
  });
}

for (const scheme of ['light', 'dark'] as const) {
  test(`text clears WCAG AA contrast floors in ${scheme} mode`, async ({ page }) => {
    await page.emulateMedia({ colorScheme: scheme });
    await page.goto(reportURL);

    const pairs = await textPairs(page);
    expect(pairs.length, 'no text elements found — the fixture rendered nothing').toBeGreaterThan(0);

    const failures: string[] = [];
    for (const pair of pairs) {
      // WCAG "large text": 18.66px bold, or 24px regular.
      const large = pair.size >= 24 || (pair.bold && pair.size >= 18.66);
      const floor = large ? 3.0 : 4.5;
      const ratio = contrastRatio(pair.fg as [number, number, number], pair.bg as [number, number, number]);
      if (ratio < floor) {
        failures.push(`${pair.selector}: ${ratio.toFixed(2)}:1 < ${floor}:1`);
      }
    }
    expect(failures, failures.join('\n')).toEqual([]);
  });
}

test('dark mode actually changes the palette', async ({ page }) => {
  const surfaceIn = async (scheme: 'light' | 'dark') => {
    await page.emulateMedia({ colorScheme: scheme });
    await page.goto(reportURL);
    return page.evaluate(() =>
      getComputedStyle(document.documentElement).getPropertyValue('--color-surface').trim(),
    );
  };
  expect(await surfaceIn('dark')).not.toBe(await surfaceIn('light'));
});
```

- [ ] **Step 2: Run**

```bash
cd visual && npx playwright test tests/tokens.spec.ts
```

Expected on current `main`: the two contrast tests may FAIL, and
`dark mode actually changes the palette` **will** FAIL — #456 has not landed,
so there is no dark palette yet.

- [ ] **Step 3: Record the pre-#456 baseline**

This is a finding, not a defect to fix here. Record the exact output on #439
as the pre-theme contrast state, then mark the dark-mode test skipped with an
explicit reason so the suite is green on `main`:

```ts
test.skip('dark mode actually changes the palette', async ({ page }) => {
```

with a comment naming #456 as the PR that unskips it. Any contrast failures in
light mode get filed on #440 and the same treatment.

**Do not use `continue-on-error` and do not weaken the floors.** A skipped test
naming its unblocking PR is visible; a lowered threshold is not.

- [ ] **Step 4: Verify the contrast assertion actually bites**

An assertion that has never failed is an assertion you cannot trust. In
`HTMLTemplates.swift`, temporarily change `--color-text-muted: #777;` to
`--color-text-muted: #EEE;` — near-white on a white surface, far below 4.5:1.

```bash
cd .. && XCHR_VISUAL_DIR="$PWD/visual/fixtures" swift test --filter VisualFixtureDumpTests
cd visual && npx playwright test tests/tokens.spec.ts
```

Expected: `text clears WCAG AA contrast floors in light mode` FAILS, naming the
offending selector and printing a ratio near 1.2:1.

**Revert the template edit before committing** — the global constraints forbid
leaving `HTMLTemplates.swift` modified. Confirm with `git diff --exit-code
Sources/XCTestHTMLReportCore/Classes/HTMLTemplates.swift`.

- [ ] **Step 5: Commit**

```bash
cd ..
git add visual/tests/tokens.spec.ts
git commit -m "WCAG contrast and dark-mode assertions, dark skipped pending #456"
```

---

### Task 9: axe-core accessibility

**Files:**
- Create: `visual/tests/a11y.spec.ts`

- [ ] **Step 1: Write the spec**

```ts
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import { pathToFileURL } from 'node:url';
import { resolve } from 'node:path';

const reportURL = pathToFileURL(resolve(__dirname, '../fixtures/report.html')).href;

// Gates on critical and serious. moderate and minor are printed for triage
// onto #440 but do not fail the run — see the spec's Scope section.
const GATING_IMPACTS = ['critical', 'serious'];

test('report has no critical or serious accessibility violations', async ({ page }) => {
  await page.goto(reportURL);
  const results = await new AxeBuilder({ page }).analyze();

  const gating = results.violations.filter((v) => GATING_IMPACTS.includes(v.impact ?? ''));
  const informational = results.violations.filter((v) => !GATING_IMPACTS.includes(v.impact ?? ''));

  if (informational.length) {
    console.log(
      'Non-gating violations (triage onto #440):\n'
        + informational.map((v) => `  [${v.impact}] ${v.id}: ${v.help}`).join('\n'),
    );
  }

  expect(
    gating.map((v) => `[${v.impact}] ${v.id}: ${v.help} (${v.nodes.length} nodes)`),
    'critical/serious accessibility violations',
  ).toEqual([]);
});
```

- [ ] **Step 2: Run and triage**

```bash
cd visual && npx playwright test tests/a11y.spec.ts
```

Expected: unknown until run — the accessibility pass has not happened. If it
fails at `critical` or `serious`, file every finding on #440, then narrow
`GATING_IMPACTS` to `['critical']` and re-run. If `critical` also fails,
narrow to `[]` **temporarily**, file the findings, and add a comment naming
#440 as the issue that restores the gate. Record whichever level you landed on
in the commit message so the narrowing is not silent.

- [ ] **Step 3: Commit**

Write the commit message against whichever of these three outcomes Step 2
produced, so the gate level is recorded rather than inferred:

```bash
cd ..
git add visual/tests/a11y.spec.ts

# Outcome A — nothing failed at critical or serious:
git commit -m "axe-core gates the report at critical and serious"

# Outcome B — serious failures existed and were filed on #440:
git commit -m "axe-core gates the report at critical; serious findings filed on #440"

# Outcome C — critical failures existed and were filed on #440:
git commit -m "axe-core runs without gating; all findings filed on #440"
```

Under outcome C the `expect` stays in the file with `GATING_IMPACTS = []`, so
the suite still reports every violation and the gate is restored by editing one
array once #440 lands.

---

### Task 10: Behavioural assertions

**Files:**
- Create: `visual/tests/behaviour.spec.ts`

- [ ] **Step 1: Write the spec**

These selectors are verified against `HTMLTemplates.swift`, not guessed:

- `classList.add('selected')` / `.remove('selected')` — `.selected` is the
  selection class.
- `document.querySelectorAll('.run.active .test-summary-group')` — group rows
  live under the active run.
- `<li onclick="showFailedScenariosOnly(this);">Failed ([[N_OF_FAILED_TESTS]])</li>`
  — the filter tabs are `<li>` elements whose text carries the count.
- Filtering sets `style.display`, so Playwright's `:visible` reflects it.

```ts
import { test, expect } from '@playwright/test';
import { pathToFileURL } from 'node:url';
import { resolve } from 'node:path';

const reportURL = pathToFileURL(resolve(__dirname, '../fixtures/report.html')).href;

test('the failed filter hides passing tests', async ({ page }) => {
  await page.goto(reportURL);

  const visibleRows = () => page.locator('.run.active .test-summary:visible').count();

  const all = await visibleRows();
  expect(all, 'fixture must render test rows').toBeGreaterThan(0);

  await page.locator('li', { hasText: /^Failed \(\d+\)$/ }).click();
  const failed = await visibleRows();

  expect(failed, 'filtering to Failed must hide rows').toBeLessThan(all);
  expect(failed, 'the fixture has failing tests, so some rows must remain').toBeGreaterThan(0);
});

test('arrow keys move the selection', async ({ page }) => {
  await page.goto(reportURL);

  await page.locator('.run.active .test-summary').first().click();
  const before = await page.locator('.selected').first().textContent();

  await page.keyboard.press('ArrowDown');
  const after = await page.locator('.selected').first().textContent();

  expect(after, 'ArrowDown must move the selection').not.toBe(before);
});
```

- [ ] **Step 2: Run**

```bash
cd visual && npx playwright test tests/behaviour.spec.ts
```

Expected: 2 tests PASS. If a selector is wrong the failure names it — re-derive
it from `HTMLTemplates.swift`, never by loosening the assertion.

- [ ] **Step 3: Commit**

```bash
cd ..
git add visual/tests/behaviour.spec.ts
git commit -m "Behavioural assertions for filters and keyboard navigation"
```

---

### Task 11: CI wiring

**Files:**
- Create: `.github/workflows/visual.yml`

- [ ] **Step 1: Write the workflow**

```yaml
name: Visual

on:
  push:
    branches: [ main ]
  pull_request:
  workflow_dispatch:

# Only reads the tree.
permissions:
  contents: read

jobs:
  # The dump needs Swift and therefore macOS. It does not need a simulator or
  # an .xcresult: the fixture is synthetic, so no cache restore and no
  # prepareTestResults.sh run appear anywhere in this workflow.
  dump:
    runs-on: macos-latest
    steps:
    - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      with:
        persist-credentials: false

    - name: Setup Xcode version
      uses: maxim-lobanov/setup-xcode@ed7a3b1fda3918c0306d1b724322adc0b8cc0a90 # v1.7.0
      with:
        xcode-version: latest-stable

    - name: Dump the synthetic render
      env:
        XCHR_VISUAL_DIR: ${{ runner.temp }}/fixtures
      run: swift test --filter VisualFixtureDumpTests

    - name: Upload fixtures
      uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a # v7.0.1
      with:
        name: visual-fixtures
        path: ${{ runner.temp }}/fixtures
        retention-days: 7

  # Browsers install faster on Linux and the expensive runner is already done.
  visual:
    needs: dump
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      with:
        persist-credentials: false

    - uses: actions/setup-node@2028fbc5c25fe9cf00d9f06a71cc4710d4507903 # v6.0.0
      with:
        node-version: 20
        cache: npm
        cache-dependency-path: visual/package-lock.json

    - name: Download fixtures
      uses: actions/download-artifact@448e3f862ab3ef47aa50ff917776823c9946035b # v5.0.0
      with:
        name: visual-fixtures
        path: visual/fixtures

    # `npm ci` against the committed lockfile, so the browser layer cannot
    # drift under a rerun.
    - name: Install
      working-directory: visual
      run: |
        npm ci
        npx playwright install --with-deps chromium

    - name: Run browser assertions
      working-directory: visual
      run: npx playwright test

    - name: Upload Playwright report
      if: always()
      uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a # v7.0.1
      with:
        name: playwright-report
        path: visual/playwright-report
        retention-days: 14
```

Confirm the `setup-node` and `download-artifact` SHAs before committing:

```bash
for r in actions/setup-node actions/download-artifact; do
  tag=$(gh api repos/$r/releases/latest --jq .tag_name)
  echo "$r $tag $(gh api repos/$r/git/ref/tags/$tag --jq .object.sha)"
done
```

- [ ] **Step 2: Lint the workflow**

```bash
zizmor --min-severity low .github/workflows/visual.yml
actionlint .github/workflows/visual.yml
```

Expected: no findings from either.

- [ ] **Step 3: Commit, push, and confirm the run is green**

```bash
git add .github/workflows/visual.yml
git commit -m "Run the browser assertions in CI"
git push
gh pr checks --watch
```

- [ ] **Step 4: Add `visual` to the required checks**

Required contexts on `main` are currently exactly `shell`, `swift`, `test`. A
green job that is not required does not gate anything.

```bash
gh api repos/:owner/:repo/branches/main/protection/required_status_checks \
  --method PATCH -f 'contexts[]=shell' -f 'contexts[]=swift' \
  -f 'contexts[]=test' -f 'contexts[]=visual'
gh api repos/:owner/:repo/branches/main/protection --jq '.required_status_checks.contexts'
```

Expected: `["shell","swift","test","visual"]`. This changes repository
settings — confirm with the maintainer before running it.

---

### Task 12: Hand the suite to #456

The spec's whole sequencing argument is that #456 becomes this suite's first
real subject. That does not happen by itself — the dark-mode test is skipped
and PR #456 predates every file in this plan.

- [ ] **Step 1: Rebase #456 onto the merged suite**

```bash
git fetch origin
git checkout tylervick/c-refresh-theme-439
git rebase origin/main
```

- [ ] **Step 2: Unskip the dark-mode test on that branch**

In `visual/tests/tokens.spec.ts`, change `test.skip(` back to `test(` for
`dark mode actually changes the palette`, and remove the comment naming #456.

- [ ] **Step 3: Run the full browser suite against the theme change**

```bash
set -o pipefail
XCHR_VISUAL_DIR="$PWD/visual/fixtures" swift test --filter VisualFixtureDumpTests
cd visual && npx playwright test
```

Expected: dark mode passes, and **both** contrast tests pass. If dark mode
clears its floors but light mode regressed, that is a real finding about the
theme change — report it on #456 rather than adjusting the test.

- [ ] **Step 4: Push and let CI confirm**

```bash
cd .. && git push --force-with-lease
gh pr checks 456 --watch
```

The `visual` check on #456 is the deliverable of this whole plan: the first
time a claim about how the report looks was verified by machine.

---

### Task 13: The retroactive capture

A one-off that produces findings, not code. Run it after Task 12 is merged.

- [ ] **Step 1: Generate fixtures once and do not regenerate**

```bash
./prepareTestResults.sh
ls -d Tests/XCTestHTMLReportTests/Resources/*.xcresult
```

Every capture below must run against this one generation. `BaselineCaptureTests`
warns that `diff -r` reports two partial directories as identical, so a capture
that silently produced nothing looks like a pass.

- [ ] **Step 2: Capture all three commits**

```bash
set -o pipefail
for sha in 72816c4 fdbe78b origin/tylervick/c-refresh-theme-439; do
  name=$(git rev-parse --short "$sha")
  git checkout "$sha" -- Sources Tests/XCTestHTMLReportTests/BaselineCaptureTests.swift
  XCHR_BASELINE_DIR="/tmp/baseline-$name" swift test --filter BaselineCaptureTests 2>&1 | tail -3
  ls -l "/tmp/baseline-$name"
done
git checkout HEAD -- Sources Tests
```

Each directory must contain three non-empty HTML files. An empty or missing
file means the capture failed — do not proceed to Step 3 with a partial set.

- [ ] **Step 3: Answer the #455 question**

```bash
diff -r /tmp/baseline-72816c4 /tmp/baseline-fdbe78b && echo "IDENTICAL — #455's zero-visual-change claim holds"
```

Record the verdict on #455 and #439 either way. A difference here is a real
finding about tokenization, not noise.

- [ ] **Step 4: Run the browser assertions against each capture**

```bash
for name in 72816c4 fdbe78b; do
  cp "/tmp/baseline-$name/TestResults.html" visual/fixtures/report.html
  (cd visual && npx playwright test tests/tokens.spec.ts --reporter=list) \
    | tee "/tmp/visual-$name.txt"
done
```

This is the payoff of Layer 3 consuming HTML rather than a build: the same
contrast assertions run against historical output. Record the contrast deltas
across the redesign on #439.

- [ ] **Step 5: Restore the working tree**

```bash
git checkout HEAD -- .
git status --porcelain
```

Expected: clean.
