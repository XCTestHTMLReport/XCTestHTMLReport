# Verification Oracle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make XCTestHTMLReport report its own failures honestly, and make its test suite runnable by anyone without secrets.

**Architecture:** Two halves, in this order. First, make fixtures self-generating so any clone (and any fork PR) can run the tests — this is a prerequisite for writing tests for the second half. Second, introduce a thread-safe fault collector that records degradation both at XCResultKit call sites and as post-conditions on the assembled model, then surface it through the CLI's exit code.

**Tech Stack:** Swift 5.5+ (swift-tools 5.5), SwiftPM, XCTest, SwiftSoup (test assertions), XCResultKit 1.2.x, ArgumentParser, GitHub Actions, `xcodebuild` / `xcrun simctl`.

## Global Constraints

- Minimum platform: `.macOS(.v10_15)` — do not raise it.
- swift-tools-version stays `5.5`.
- Public API changes ship in **3.0**. Faults are fatal by default; `--lenient` restores 2.x exit behavior.
- No new third-party dependencies.
- CI must run with **zero repository secrets**. Any step requiring a secret is a plan violation.
- Structural assertions only in tests — no golden-file diffing of generated HTML.
- Fault collection must be thread-safe: parsing runs concurrently behind `DispatchQueue` locks (`Run.swift:93`, `Test.swift:106`).

## Sequencing Note

The design spec listed A1 (fault collection) before A2 (self-contained fixtures). Reading the
code inverted this: A1's tests need a fixture to run against, and today the only fixtures come
from a private R2 bucket. Generating fixtures locally must land first or A1 cannot be
test-driven. Tasks 1–2 are A2; Tasks 3–8 are A1.

---

### Task 1: Make the fixture generator work on current Xcode

`prepareTestResults.sh` hardcodes an "iPhone 12" simulator that does not exist in Xcode 26, so
fixture regeneration is dead. `testDownloadAndAttachWebData` fetches `https://apple.com` at
test time, making fixture generation network-dependent and flaky.

**Files:**
- Modify: `prepareTestResults.sh`
- Modify: `XCTestHTMLReportSampleApp/SampleAppUITests/FirstSuite.swift:35-49`

**Interfaces:**
- Consumes: nothing (first task)
- Produces: `prepareTestResults.sh` writes `TestResults.xcresult`, `SanityResults.xcresult`, and
  `RetryResults.xcresult` into `Tests/XCTestHTMLReportTests/Resources/`. Task 2 depends on this
  contract.

- [ ] **Step 1: Replace the hardcoded simulator with dynamic resolution**

Replace the `SIM_DESTINATION` assignment and the `simctl create` block at the top of
`prepareTestResults.sh` (everything from `SIM_DESTINATION=` through the `set -e` after the
device check) with:

```bash
# Pick the newest available iPhone simulator rather than hardcoding a model that
# Apple eventually removes. Falls back to the generic destination if none is found.
DEVICE_NAME=$(xcrun simctl list devices available --json \
    | python3 -c "
import json, sys
devices = json.load(sys.stdin)['devices']
names = [d['name'] for runtime in devices for d in devices[runtime] if d['name'].startswith('iPhone')]
print(sorted(names)[-1] if names else '')
")

if [[ -z "$DEVICE_NAME" ]]; then
    echo "No iPhone simulator available" >&2
    exit 1
fi

echo "Using simulator: $DEVICE_NAME"
SIM_DESTINATION="platform=iOS Simulator,name=${DEVICE_NAME},OS=latest"
```

- [ ] **Step 2: Run it and verify all three bundles are produced**

Run: `./prepareTestResults.sh`
Expected: exits 0, prints "successfully finished", and
`ls Tests/XCTestHTMLReportTests/Resources/` shows `TestResults.xcresult`,
`SanityResults.xcresult`, and `RetryResults.xcresult`.

- [ ] **Step 3: Remove the network dependency from the sample test**

In `XCTestHTMLReportSampleApp/SampleAppUITests/FirstSuite.swift`, replace the whole
`testDownloadAndAttachWebData` function with:

```swift
    func testAttachHtmlData() {
        // Previously fetched https://apple.com, which made fixture generation
        // network-dependent. The attachment only needs to be public.html data.
        let markup = """
        <!doctype html>
        <html><head><title>Sample</title></head>
        <body><p>Sample attachment body</p></body></html>
        """
        let html = XCTAttachment(
            data: Data(markup.utf8),
            uniformTypeIdentifier: "public.html"
        )
        html.name = "HTML"
        html.lifetime = .keepAlways
        add(html)
    }
```

- [ ] **Step 4: Regenerate fixtures with networking disabled to prove independence**

Run: `./prepareTestResults.sh`
Expected: exits 0. The run must not depend on `apple.com`; if you want to prove it, disconnect
from the network first — the script should still succeed.

- [ ] **Step 5: Commit**

```bash
git add prepareTestResults.sh XCTestHTMLReportSampleApp/SampleAppUITests/FirstSuite.swift
git commit -m "fix: make fixture generation work on current Xcode and offline

Resolve the newest available iPhone simulator instead of hardcoding
iPhone 12, which no longer exists in Xcode 26. Replace the apple.com
fetch with inline HTML data so fixture generation has no network
dependency."
```

---

### Task 2: Self-contained CI that needs no secrets

`test.yml` and `codecov.yml` pull fixtures from a private R2 bucket via repo secrets, so fork
PRs can never go green. This is the direct cause of issue #219.

**Files:**
- Create: `.github/workflows/test.yml` (replacing the existing file wholesale)
- Delete: `.travis.yml`

**Interfaces:**
- Consumes: `prepareTestResults.sh` from Task 1
- Produces: a `test` job that runs on `pull_request` from forks with no secrets. Task 7 tightens
  the assertions this job runs.

- [ ] **Step 1: Replace `.github/workflows/test.yml` entirely**

```yaml
name: Test

on:
  push:
    branches: [ "main" ]
  pull_request:
  workflow_dispatch:

jobs:
  test:
    runs-on: macos-latest
    steps:
    - uses: actions/checkout@v4

    - name: Setup Xcode version
      uses: maxim-lobanov/setup-xcode@v1.6.0
      with:
        xcode-version: latest-stable

    - name: Generate test fixtures
      run: ./prepareTestResults.sh

    - name: Run tests
      run: swift test -v

    - name: Upload fixtures on failure
      if: failure()
      uses: actions/upload-artifact@v4
      with:
        name: xcresult-fixtures
        path: Tests/XCTestHTMLReportTests/Resources
        retention-days: 7
```

Note the `pull_request` trigger has no `branches` filter, so fork PRs targeting any branch run.
There are no `secrets` references anywhere in this file — that is the point of the task.

- [ ] **Step 2: Delete the dead Travis config**

```bash
git rm .travis.yml
```

- [ ] **Step 3: Verify the workflow reproduces locally**

Run: `./prepareTestResults.sh && swift test -v`
Expected: fixtures generate, then the existing test suite runs. Some tests may fail — that is
acceptable at this step and is exactly what Tasks 3–7 address. What must be true: the suite
runs at all, with no secrets and no R2 access.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/test.yml .travis.yml
git commit -m "ci: generate fixtures in CI instead of fetching from private bucket

Fork PRs could never go green because fixtures came from an R2 bucket
behind repo secrets. CI now runs prepareTestResults.sh to build its own
xcresult bundles. Closes the root cause of #219.

Also removes the long-dead .travis.yml."
```

---

### Task 3: Fault model and thread-safe collector

**Files:**
- Create: `Sources/XCTestHTMLReportCore/Classes/Helpers/FaultCollector.swift`
- Test: `Tests/XCTestHTMLReportTests/FaultCollectorTests.swift`

**Interfaces:**
- Consumes: nothing
- Produces:
  - `public struct Fault: Equatable` with `public let kind: Fault.Kind`, `public let detail: String`
  - `public enum Fault.Kind: String` with cases `missingInvocationRecord`, `unresolvedAttachment`, `payloadExportFailed`, `logExportFailed`
  - `public final class FaultCollector` with `public init()`, `public func record(_ kind: Fault.Kind, _ detail: String)`, `public var faults: [Fault]` (thread-safe read), `public var isEmpty: Bool`
  - Tasks 4, 5, and 6 all consume this type.

- [ ] **Step 1: Write the failing test**

Create `Tests/XCTestHTMLReportTests/FaultCollectorTests.swift`:

```swift
import Foundation
import XCTest
@testable import XCTestHTMLReportCore

final class FaultCollectorTests: XCTestCase {
    func testStartsEmpty() {
        let collector = FaultCollector()
        XCTAssertTrue(collector.isEmpty)
        XCTAssertEqual(collector.faults.count, 0)
    }

    func testRecordsFaultWithKindAndDetail() {
        let collector = FaultCollector()
        collector.record(.unresolvedAttachment, "attachment-1")

        XCTAssertFalse(collector.isEmpty)
        XCTAssertEqual(collector.faults.count, 1)
        XCTAssertEqual(collector.faults[0].kind, .unresolvedAttachment)
        XCTAssertEqual(collector.faults[0].detail, "attachment-1")
    }

    func testConcurrentRecordingDoesNotLoseFaults() {
        let collector = FaultCollector()
        let iterations = 1000

        DispatchQueue.concurrentPerform(iterations: iterations) { index in
            collector.record(.payloadExportFailed, "payload-\(index)")
        }

        XCTAssertEqual(collector.faults.count, iterations)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter FaultCollectorTests`
Expected: FAIL — "cannot find 'FaultCollector' in scope"

- [ ] **Step 3: Write the implementation**

Create `Sources/XCTestHTMLReportCore/Classes/Helpers/FaultCollector.swift`:

```swift
//
//  FaultCollector.swift
//  XCTestHTMLReportCore
//
//  Records degradation encountered while assembling a report so the CLI can
//  exit non-zero instead of claiming success on an incomplete report.
//

import Foundation

/// A single instance of report degradation.
public struct Fault: Equatable {
    public enum Kind: String {
        case missingInvocationRecord
        case unresolvedAttachment
        case payloadExportFailed
        case logExportFailed
    }

    public let kind: Kind
    public let detail: String

    public init(kind: Kind, detail: String) {
        self.kind = kind
        self.detail = detail
    }
}

/// Thread-safe accumulator for `Fault`s.
///
/// Parsing runs concurrently (see `Run.swift` and `Test.swift`), so every
/// mutation is serialized behind a private queue.
public final class FaultCollector {
    private var storage: [Fault] = []
    private let queue = DispatchQueue(label: "com.xchtmlreport.faults")

    public init() {}

    public func record(_ kind: Fault.Kind, _ detail: String) {
        queue.sync { storage.append(Fault(kind: kind, detail: detail)) }
    }

    public var faults: [Fault] {
        queue.sync { storage }
    }

    public var isEmpty: Bool {
        queue.sync { storage.isEmpty }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter FaultCollectorTests`
Expected: PASS — all three tests green.

- [ ] **Step 5: Commit**

```bash
git add Sources/XCTestHTMLReportCore/Classes/Helpers/FaultCollector.swift Tests/XCTestHTMLReportTests/FaultCollectorTests.swift
git commit -m "feat: add thread-safe fault collector

Foundation for reporting degraded output. Parsing is concurrent, so
mutations serialize behind a private dispatch queue."
```

---

### Task 4: Record faults at XCResultKit call sites

XCResultKit signals failure by returning `nil` and printing to stderr; it exposes no structured
errors. Record a fault wherever we already handle a `nil` return.

This task also fixes a real bug found while reading `Summary.init`: it uses `break` when an
invocation record is unreadable, which silently abandons every *remaining* result bundle when
multiple are passed.

**Files:**
- Modify: `Sources/XCTestHTMLReportCore/Classes/Models/ResultFile.swift`
- Modify: `Sources/XCTestHTMLReportCore/Classes/Models/Summary.swift:20-45`
- Test: `Tests/XCTestHTMLReportTests/FaultReportingTests.swift` (create)

**Interfaces:**
- Consumes: `FaultCollector`, `Fault.Kind` from Task 3
- Produces:
  - `ResultFile.init(url: URL, faultCollector: FaultCollector)`
  - `Summary.init(resultPaths:renderingMode:downsizeImagesEnabled:downsizeScaleFactor:faultCollector:)` — new trailing parameter, defaulted to a fresh `FaultCollector()` so existing call sites compile
  - `public var Summary.faults: [Fault]` — Task 5 and Task 6 read this

- [ ] **Step 1: Write the failing test**

Create `Tests/XCTestHTMLReportTests/FaultReportingTests.swift`:

```swift
import XCTest
@testable import XCTestHTMLReportCore

final class FaultReportingTests: XCTestCase {
    func testMissingInvocationRecordIsRecordedAsFault() throws {
        let bogusPath = NSTemporaryDirectory() + "/DoesNotExist.xcresult"
        let collector = FaultCollector()

        let summary = Summary(
            resultPaths: [bogusPath],
            renderingMode: .linking,
            downsizeImagesEnabled: false,
            downsizeScaleFactor: 0.25,
            faultCollector: collector
        )

        XCTAssertFalse(summary.faults.isEmpty)
        XCTAssertTrue(summary.faults.contains { $0.kind == .missingInvocationRecord })
    }

    func testCleanFixtureProducesNoFaults() throws {
        let url = try XCTUnwrap(
            Bundle.testBundle.url(forResource: "SanityResults", withExtension: "xcresult")
        )
        let collector = FaultCollector()

        let summary = Summary(
            resultPaths: [url.path],
            renderingMode: .linking,
            downsizeImagesEnabled: false,
            downsizeScaleFactor: 0.25,
            faultCollector: collector
        )
        _ = summary.generatedHtmlReport()

        XCTAssertEqual(summary.faults, [], "Clean fixture must not produce faults")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter FaultReportingTests`
Expected: FAIL — "extra argument 'faultCollector' in call"

- [ ] **Step 3: Thread the collector through `ResultFile`**

In `ResultFile.swift`, change the stored properties and initializer:

```swift
class ResultFile {
    let url: URL
    private let relativeUrl: URL
    private let file: XCResultFile
    let faultCollector: FaultCollector

    init(url: URL, faultCollector: FaultCollector) {
        self.url = url
        self.faultCollector = faultCollector
        relativeUrl = URL(fileURLWithPath: url.lastPathComponent)
        file = XCResultFile(url: url)
    }
```

Then record a fault at each existing `nil` path. In `exportPayload(id:fileName:)`:

```swift
    func exportPayload(id: String, fileName: String?) -> URL? {
        guard let savedURL = file.exportPayload(id: id) else {
            Logger.warning("Can't export payload with id \(id)")
            faultCollector.record(.payloadExportFailed, "payload id \(id)")
            return nil
        }
```

In `exportPayloadData(id:)`:

```swift
    func exportPayloadData(id: String) -> Data? {
        guard let savedURL = file.exportPayload(id: id) else {
            Logger.warning("Can't export payload with id \(id)")
            faultCollector.record(.payloadExportFailed, "payload id \(id)")
            return nil
        }
```

In `exportLogs(id:)` and `exportLogsData(id:)`, replace each
`Logger.warning("Can't get logss with id \(id)")` guard body with:

```swift
            Logger.warning("Can't get logs with id \(id)")
            faultCollector.record(.logExportFailed, "log id \(id)")
            return nil
```

- [ ] **Step 4: Thread the collector through `Summary` and fix the `break` bug**

In `Summary.swift`, add a stored property and replace the initializer:

```swift
public struct Summary {
    let runs: [Run]
    let resultFiles: [ResultFile]
    private let faultCollector: FaultCollector

    public enum RenderingMode {
        case inline
        case linking
    }

    /// All degradation encountered while building this report.
    public var faults: [Fault] {
        faultCollector.faults
    }

    public init(
        resultPaths: [String],
        renderingMode: RenderingMode,
        downsizeImagesEnabled: Bool,
        downsizeScaleFactor: CGFloat,
        faultCollector: FaultCollector = FaultCollector()
    ) {
        var runs: [Run] = []
        var resultFiles: [ResultFile] = []
        self.faultCollector = faultCollector

        for resultPath in resultPaths {
            Logger.step("Parsing \(resultPath)")
            let url = URL(fileURLWithPath: resultPath)
            let resultFile = ResultFile(url: url, faultCollector: faultCollector)
            resultFiles.append(resultFile)
            guard let invocationRecord = resultFile.getInvocationRecord() else {
                Logger.warning("Can't find invocation record for : \(resultPath)")
                faultCollector.record(.missingInvocationRecord, resultPath)
                // Previously `break`, which silently abandoned every remaining
                // bundle when multiple were passed.
                continue
            }
            let resultRuns = invocationRecord.actions.compactMap {
                Run(
                    action: $0,
                    file: resultFile,
                    renderingMode: renderingMode,
                    downsizeImagesEnabled: downsizeImagesEnabled,
                    downsizeScaleFactor: downsizeScaleFactor
                )
            }
            runs.append(contentsOf: resultRuns)
        }
        self.runs = runs
        self.resultFiles = resultFiles
    }
```

- [ ] **Step 5: Fix any other `ResultFile(url:)` call sites the compiler flags**

Run: `swift build 2>&1 | grep "error:"`
Expected: zero errors. If the compiler reports a `ResultFile(url:)` call missing its
`faultCollector` argument, pass the enclosing `Summary`'s collector through — never construct a
fresh `FaultCollector()` at an interior call site, or its faults will be silently discarded.

- [ ] **Step 6: Run test to verify it passes**

Run: `swift test --filter FaultReportingTests`
Expected: PASS — both tests green.

- [ ] **Step 7: Commit**

```bash
git add Sources/XCTestHTMLReportCore/Classes/Models/ResultFile.swift Sources/XCTestHTMLReportCore/Classes/Models/Summary.swift Tests/XCTestHTMLReportTests/FaultReportingTests.swift
git commit -m "feat: record faults at XCResultKit call sites

XCResultKit signals failure by returning nil, so record a fault wherever
we already handle one. Also fixes Summary.init using break instead of
continue, which silently abandoned every remaining result bundle after
one unreadable bundle."
```

---

### Task 5: Post-condition check for unresolved attachments

Call-site checks alone are insufficient. In the 2026-08-06 smoke test, XCResultKit failed to
decode *nested* attachment metadata (`Reference.swift:51`) while the top-level calls still
returned non-nil, so a call-site check would have missed it. The observable symptom is an
`Attachment` whose `content` is `RenderingContent.none` — rendered as an empty `src`.

**Files:**
- Modify: `Sources/XCTestHTMLReportCore/Classes/Models/Summary.swift`
- Test: `Tests/XCTestHTMLReportTests/FaultReportingTests.swift` (extend)

**Interfaces:**
- Consumes: `Summary.faults`, `Fault.Kind.unresolvedAttachment` from Tasks 3–4;
  `Summary.allAttachments` (already exists via `ContainingAttachment`); `RenderingContent`
- Produces: `public func Summary.validate()` — Task 6 calls this before reading `faults`

- [ ] **Step 1: Write the failing test**

Append to `Tests/XCTestHTMLReportTests/FaultReportingTests.swift`, inside the existing class:

```swift
    func testValidateFlagsUnresolvedAttachments() throws {
        let url = try XCTUnwrap(
            Bundle.testBundle.url(forResource: "TestResults", withExtension: "xcresult")
        )
        let collector = FaultCollector()

        let summary = Summary(
            resultPaths: [url.path],
            renderingMode: .linking,
            downsizeImagesEnabled: false,
            downsizeScaleFactor: 0.25,
            faultCollector: collector
        )
        summary.validate()

        // Every attachment the model knows about must have resolved to real
        // content. An unresolved one renders as an empty src.
        let unresolved = summary.faults.filter { $0.kind == .unresolvedAttachment }
        XCTAssertEqual(
            unresolved, [],
            "Unresolved attachments: \(unresolved.map(\.detail))"
        )
    }

    func testValidateIsIdempotent() throws {
        let url = try XCTUnwrap(
            Bundle.testBundle.url(forResource: "SanityResults", withExtension: "xcresult")
        )
        let summary = Summary(
            resultPaths: [url.path],
            renderingMode: .linking,
            downsizeImagesEnabled: false,
            downsizeScaleFactor: 0.25
        )

        summary.validate()
        let afterFirst = summary.faults.count
        summary.validate()

        XCTAssertEqual(summary.faults.count, afterFirst, "validate() must not double-record")
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter FaultReportingTests`
Expected: FAIL — "value of type 'Summary' has no member 'validate'"

- [ ] **Step 3: Implement `validate()`**

Add to `Summary.swift`, inside the `public struct Summary` body:

```swift
    /// Check post-conditions on the assembled model and record any degradation.
    ///
    /// Call-site checks catch failures XCResultKit surfaces as `nil`. They do
    /// not catch failures in *nested* decoding, where a parent object still
    /// decodes but a child field comes back empty. The observable symptom is an
    /// attachment that resolved to no content, so check for that directly.
    ///
    /// Idempotent: repeated calls do not duplicate faults.
    public func validate() {
        let alreadyFlagged = Set(
            faultCollector.faults
                .filter { $0.kind == .unresolvedAttachment }
                .map(\.detail)
        )

        for attachment in allAttachments {
            guard case .none = attachment.content else { continue }
            let detail = attachment.filename
            guard !alreadyFlagged.contains(detail) else { continue }
            faultCollector.record(.unresolvedAttachment, detail)
        }
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter FaultReportingTests`
Expected: PASS.

If `testValidateFlagsUnresolvedAttachments` fails with a non-empty list, **do not weaken the
assertion.** That is a real bug in attachment resolution on your Xcode version, and it is
exactly what this plan exists to surface. Record it as a GitHub issue under the 3.0 milestone,
then mark this test `XCTSkip` with the issue number in the skip reason so the rest of the plan
can proceed:

```swift
        throw XCTSkip("Unresolved attachments on this Xcode version — see issue #NNN")
```

- [ ] **Step 5: Commit**

```bash
git add Sources/XCTestHTMLReportCore/Classes/Models/Summary.swift Tests/XCTestHTMLReportTests/FaultReportingTests.swift
git commit -m "feat: flag attachments that resolved to no content

Call-site nil checks miss nested XCResultKit decode failures, where the
parent decodes but a child comes back empty. Check the assembled model
directly for attachments with no content."
```

---

### Task 6: Honest exit codes and `--lenient`

**Files:**
- Modify: `Sources/XCTestHTMLReport/XCTestHtmlReport.swift`
- Test: `Tests/XCTestHTMLReportTests/CliTests.swift` (extend)

**Interfaces:**
- Consumes: `Summary.validate()`, `Summary.faults`, `Fault` from Tasks 3–5
- Produces: CLI exit code `3` on faults; `--lenient` flag restoring exit `0`. Task 7 asserts on
  these.

- [ ] **Step 1: Write the failing test**

Append to `Tests/XCTestHTMLReportTests/CliTests.swift`, inside the existing class:

```swift
    func testLenientFlagIsAccepted() throws {
        let testResultsUrl = try XCTUnwrap(testResultsUrl)
        let (status, maybeStdOut, _) = try xchtmlreportCmd(
            args: ["--lenient", testResultsUrl.path]
        )

        // --lenient never fails on faults, so a readable bundle always exits 0.
        XCTAssertEqual(status, 0)
        try XCTAssertContains(try XCTUnwrap(maybeStdOut), "successfully created")
    }

    func testUnreadableBundleExitsNonZeroWithFaultSummary() throws {
        let bogus = NSTemporaryDirectory() + "/DoesNotExist.xcresult"
        try? FileManager.default.createDirectory(
            atPath: bogus, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(atPath: bogus) }

        let (status, maybeStdOut, maybeStdErr) = try xchtmlreportCmd(args: [bogus])

        XCTAssertEqual(status, 3, "Faults must produce exit code 3")
        let combined = (maybeStdOut ?? "") + (maybeStdErr ?? "")
        try XCTAssertContains(combined, "missingInvocationRecord")
    }

    func testUnreadableBundleExitsZeroUnderLenient() throws {
        let bogus = NSTemporaryDirectory() + "/DoesNotExistLenient.xcresult"
        try? FileManager.default.createDirectory(
            atPath: bogus, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(atPath: bogus) }

        let (status, _, _) = try xchtmlreportCmd(args: ["--lenient", bogus])

        XCTAssertEqual(status, 0, "--lenient restores 2.x exit behaviour")
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter CliTests`
Expected: FAIL — the `--lenient` runs fail with "Unknown option '--lenient'" (exit 64), and
`testUnreadableBundleExitsNonZeroWithFaultSummary` gets status 0 instead of 3.

- [ ] **Step 3: Add the flag**

In `XCTestHtmlReport.swift`, add to the `XCTestHtmlReport` struct alongside the existing
`verbose` flag:

```swift
    @Flag(
        name: .long,
        help: ArgumentHelp(
            "Exit successfully even when the report is degraded (pre-3.0 behaviour)"
        )
    )
    var lenient = false
```

- [ ] **Step 4: Validate and exit on faults**

In `XCTestHtmlReport.run()`, replace the line `let summary = Summary(` … through the closing
`)` of that call with an explicit collector:

```swift
        let faultCollector = FaultCollector()
        let summary = Summary(
            resultPaths: summaryOptions.finalResults,
            renderingMode: summaryOptions.finalRenderingMode,
            downsizeImagesEnabled: summaryOptions.downsizeImages,
            downsizeScaleFactor: summaryOptions.downsizeScaleFactor,
            faultCollector: faultCollector
        )
```

Then, at the very end of `run()` — after the JSON block, so every output is still written —
append:

```swift
        summary.validate()
        let faults = summary.faults
        guard !faults.isEmpty else { return }

        Logger.warning("Report is degraded: \(faults.count) fault(s)")
        for fault in faults {
            Logger.warning("  \(fault.kind.rawValue): \(fault.detail)")
        }

        if lenient {
            Logger.warning("Continuing anyway because --lenient was passed")
            return
        }

        Logger.error("Exiting non-zero. Pass --lenient to ignore faults.")
        throw ExitCode(3)
```

Reports are still written before the exit — a degraded report is more useful than none, and
this keeps `--lenient` a pure exit-code switch.

- [ ] **Step 5: Run test to verify it passes**

Run: `swift test --filter CliTests`
Expected: PASS — all CLI tests green.

- [ ] **Step 6: Commit**

```bash
git add Sources/XCTestHTMLReport/XCTestHtmlReport.swift Tests/XCTestHTMLReportTests/CliTests.swift
git commit -m "feat!: exit non-zero when the report is degraded

BREAKING CHANGE: xchtmlreport now exits 3 when it could not fully parse
the result bundle, instead of exiting 0 with a success message. Reports
are still written. Pass --lenient for pre-3.0 behaviour."
```

---

### Task 7: Close the hole in the test harness

`TestSupport.swift` asserts stderr is empty only under `#if !DEBUG`, with the comment
"XCResultKit outputs non-fatals to stderr in debug mode". `swift test` builds debug, so that
assertion never runs in CI. The suite is structurally unable to notice degradation.

**Files:**
- Modify: `Tests/XCTestHTMLReportTests/TestSupport.swift:127-145`

**Interfaces:**
- Consumes: exit code `3` semantics from Task 6
- Produces: `parseReportDocument(xchtmlreportArgs:)` now fails any test whose run reports faults

- [ ] **Step 1: Replace the stderr check with a fault check**

In `TestSupport.swift`, replace the body of `parseReportDocument` with:

```swift
    func parseReportDocument(xchtmlreportArgs: [String]) throws -> Document {
        try XCTContext.runActivity(named: #function) { _ in
            let (
                status,
                maybeStdOut,
                maybeStdErr
            ) = try xchtmlreportCmd(args: xchtmlreportArgs)

            // Exit 3 means the tool collected faults. Previously this harness
            // only checked stderr, and only in release builds — so `swift test`
            // (always debug) could never see degradation at all.
            let stdErr = maybeStdErr ?? ""
            XCTAssertEqual(
                status, 0,
                "xchtmlreport exited \(status). stderr:\n\(stdErr)"
            )

            let stdOut = try XCTUnwrap(maybeStdOut)
            XCTAssertFalse(
                stdOut.contains("Report is degraded"),
                "Report was degraded:\n\(stdOut)"
            )

            let htmlUrl = try XCTUnwrap(urlFromXCHtmlreportStdout(stdOut))
            let htmlString = try String(contentsOf: htmlUrl, encoding: .utf8)
            return try SwiftSoup.parse(htmlString)
        }
    }
```

- [ ] **Step 2: Run the full suite**

Run: `swift test`
Expected: PASS. If a test now fails because the tool reports faults on your fixtures, that is a
genuine defect this plan was built to expose — file it under the 3.0 milestone and `XCTSkip`
the affected test with the issue number, exactly as in Task 5 Step 4. Do not restore the
`#if !DEBUG` guard.

- [ ] **Step 3: Commit**

```bash
git add Tests/XCTestHTMLReportTests/TestSupport.swift
git commit -m "test: fail tests when the tool reports a degraded report

The stderr assertion was guarded by #if !DEBUG, and swift test always
builds debug — so the suite could never observe degradation. Check the
exit code and the fault summary instead."
```

---

### Task 8: Document the new contract

**Files:**
- Modify: `CONTRIBUTING.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: everything above
- Produces: nothing consumed by later tasks

- [ ] **Step 1: Add a build-and-test section to CONTRIBUTING.md**

Insert immediately after the `## Submitting Pull Requests` heading paragraph:

```markdown
### Building and testing

The test suite runs against real `.xcresult` bundles. Generate them once, then
run the tests:

```bash
./prepareTestResults.sh   # builds the sample app and produces fixtures
swift test
```

`prepareTestResults.sh` picks the newest available iPhone simulator automatically.
No credentials or secrets are required — CI runs exactly these two commands, so a
green run locally means a green run on your pull request.

Regenerate fixtures after upgrading Xcode; `.xcresult` contents change between
Xcode versions.
```

- [ ] **Step 2: Document exit codes in README.md**

Insert a new section immediately before `## Fastlane Support`:

```markdown
## Exit codes

| Code | Meaning |
| --- | --- |
| 0 | Report generated successfully |
| 3 | Report was generated but is **degraded** — some of the result bundle could not be parsed |
| 64 | Invalid arguments |

Starting in 3.0, `xchtmlreport` exits non-zero when it cannot fully parse a result
bundle. Earlier versions exited 0 and printed a success message even when parts of
the report were missing, so pipelines had no way to detect an incomplete report.

The report is still written when faults occur. To restore the pre-3.0 behaviour and
always exit 0, pass `--lenient`.
```

- [ ] **Step 3: Verify docs match reality**

Run: `swift run xchtmlreport --help`
Expected: `--lenient` appears in the output with its help text. Confirm the README's exit-code
table matches the codes actually produced by Task 6's tests.

- [ ] **Step 4: Commit**

```bash
git add CONTRIBUTING.md README.md
git commit -m "docs: document exit codes and how to run the test suite

CONTRIBUTING never explained how to run tests, which was moot while
fixtures lived behind repo secrets. Both are now accurate."
```

---

## Verification

After all tasks, from a clean checkout:

```bash
./prepareTestResults.sh
swift build 2>&1 | grep -c "error:"   # expect 0
swift test                             # expect all green
```

Then confirm the oracle actually works — this is the whole point of the plan:

```bash
# A readable bundle exits 0
swift run xchtmlreport Tests/XCTestHTMLReportTests/Resources/SanityResults.xcresult
echo "exit=$?"    # expect 0

# A degraded bundle exits 3 and says why
mkdir -p /tmp/Broken.xcresult
swift run xchtmlreport /tmp/Broken.xcresult
echo "exit=$?"    # expect 3, with a "Report is degraded" summary

# --lenient restores the old behaviour
swift run xchtmlreport --lenient /tmp/Broken.xcresult
echo "exit=$?"    # expect 0
```

## Follow-on work (not in this plan)

Tracked separately under the 3.0 milestone:

- **D1/D2:** Dependabot config, release pipeline repair
- **B:** propose-only triage lane
- **D3:** Xcode drift detector — unblocked by this plan
- **A3:** fixture coverage gaps, Swift Testing first
- `codecov.yml` still references the R2 bucket; fold it into the Task 2 pattern or delete it
- `HTMLTemplates.swift` still claims to be generated by a script deleted in 2022
