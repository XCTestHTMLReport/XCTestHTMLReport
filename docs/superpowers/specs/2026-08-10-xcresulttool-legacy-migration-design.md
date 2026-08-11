# Migrating off `xcresulttool --legacy`

Design spec for [#391](https://github.com/XCTestHTMLReport/XCTestHTMLReport/issues/391). Milestone 3.0.

## Problem

`XCResultKit` drives `xcrun xcresulttool get --format json --legacy`. Apple has
deprecated the legacy commands and will remove them. When that lands,
`xchtmlreport` stops working entirely.

Two hops of the chain are outside our control: upstream
`davidahouse/XCResultKit` last shipped v1.2.2 on 2025-02-23, and its own
tracking issue (davidahouse/XCResultKit#58, "Stop using --legacy") is open and
unaddressed.

## Decision

**Read the new `xcresulttool` format directly and drop the XCResultKit
dependency**, behind a reader abstraction that keeps the legacy path alive until
Apple removes it.

Rejected alternatives:

- **Contribute upstream.** XCResultKit's public API *is* the legacy object
  graph — `ActionsInvocationRecord`, `ActionTestSummaryGroup`, and friends are
  one-to-one with legacy JSON types. Migrating it means proposing a breaking
  API redesign to a maintainer who has not responded to the tracking issue in
  over a year, and blocking an existential risk on a third party's response.
- **Vendor/fork XCResultKit.** Solves "upstream is unresponsive" but not "the
  format is being removed" — the vendored code still shells out to `--legacy`.
  Inherits 3,549 lines across 78 files, of which we use roughly 15 types, and
  we would still have to write the new-format reader.

Under all three options we must write a new-format reader. Once it exists the
dependency is dead weight, so the direct read is strictly less work for the
same outcome.

## What the new format actually provides

Everything below was measured against freshly generated fixtures on
**Xcode 26.2 (17C52), xcresulttool 24514, schema 0.1.0, legacy format 3.56**.
Numbers and shapes are observations, not estimates.

### The central finding: the new format is not a superset

| Legacy | New format | Verdict |
| --- | --- | --- |
| activity `activityType` (5 constants driving CSS classes) | absent; only `isAssociatedWithFailure: Bool` | **lost** |
| activity `start` **and** `finish` | `startTime` only | **lost** — per-activity duration is not derivable |
| activity `uuid` | absent | synthesized locally (already how the HTML uses it) |
| attachment `name` (user-supplied, e.g. `"HTML"`) | `name` holds the legacy *filename* | **lost** — present only in a sibling child-activity title |
| attachment `filename` | `name` | maps, renamed |
| attachment `uniformTypeIdentifier` | absent | derived from `exportedFileName` extension |
| attachment `payloadRef.id` | `payloadId` | present, but payload-by-id export is itself a legacy command |
| `ActionTestFailureSummary.fileName` / `.lineNumber` / `.issueType` | one string: `"RetryTests.swift:31: XCTAssertTrue failed"` | **lost as structure** |
| log section `emittedOutput` | absent; structured `messages` instead | **lost** |
| `exportRecursiveJson()` (drives `--json`) | no equivalent | **no replacement** |
| repetitions (duplicate siblings + `repetitionPolicySummary`) | first-class `nodeType: "Repetition"` | **improved** |
| tree shape | two fewer wrapper levels | differs, see below |

Consequence: byte-identical output across the two backends is not achievable.
The bar is a *declared and reviewed* diff, asserted in CI, not an empty one.

### Tree shape

```
LEGACY   SampleAppUnitTests → "All tests" → "SampleAppUnitTests.xctest" → SampleAppUnitTests → tests
                            → "SwiftTestingSuite" → tests          (sibling of "All tests")

MODERN   SampleAppUnitTests → SampleAppUnitTests → tests
                            → SwiftTestingSuite  → tests           (consistent siblings)
```

The modern reader renders the natural flat tree. Synthesizing the wrappers was
rejected: `"Selected tests"` versus `"All tests"` depends on run filtering,
which the new format does not expose, so one of the two labels would always be
fabricated. The modern tree is also the more consistent one — legacy places
Swift Testing suites at a different depth than XCTest suites.

Swift Testing display names also differ: legacy reports
`taggedMultiplication()`, modern reports the `@Test` display name
`Tagged multiplication check`.

### Attachments

`xcresulttool export attachments --path B --output-path D` exports **every**
attachment in the bundle in a single call (measured: 0.05s on `TestResults`),
writing `<attachment-uuid>.<ext>` files plus a `manifest.json`. The manifest
carries `exportedFileName`, `suggestedHumanReadableName`,
`isAssociatedWithFailure`, `timestamp`, `deviceId`, `configurationName`, and
`testIdentifier` — but **not** the attachment `uuid` as a field, and **not** the
UTI.

The join is: `activities[].attachments[].uuid` ↔ basename of
`manifest[].attachments[].exportedFileName`. Verified on `TestResults`:
activity uuid `4DB9AD3F-E485-4F77-9771-8FAC7270E261` ↔ exported file
`4DB9AD3F-E485-4F77-9771-8FAC7270E261.mp4`. Attachment type comes from the file
extension.

This replaces the legacy one-subprocess-per-payload export, and with it the
per-payload lock table in `ResultFile` that exists solely because XCResultKit
exports every caller of an id to one shared temp path.

### Performance

Same-runner interleaved A/B on `TestResults.xcresult`, 5 reps each, alternating
legacy/modern per rep to cancel drift:

| Backend | Subprocess spawns | Median | Min |
| --- | --- | --- | --- |
| legacy | 27 | 0.74s | 0.71s |
| modern | 20 | 0.76s | 0.75s |

**No performance claim is being made in either direction.** These are equal
within noise on one machine and one bundle size. The point of measuring was to
rule out the modern path being dramatically worse because `activities` is
per-test-id; it is not. Do not cite these numbers as a speedup, and do not
compare them against numbers from a different runner.

## Architecture

One port, two adapters. New directory:

```
Sources/XCTestHTMLReportCore/Classes/ResultReading/
  ParsedResult.swift                backend-neutral model (the port)
  ResultReader.swift                protocol: read() throws -> ParsedResult
  ResultBackend.swift               detection + override
  Legacy/LegacyResultReader.swift   XCResultKit  → ParsedResult
  Modern/ModernResultReader.swift   xcresulttool → ParsedResult
  Modern/XCResultToolClient.swift   subprocess + JSON decode, schema-version pinned
  Modern/TestResultsSchema.swift    Codable structs for the new format
```

`Classes/Models/*` stop importing XCResultKit and build from `ParsedResult`.
This is the only shape in which dual-path does not duplicate the renderer.

**HTML templates do not change.** `HTMLTemplates.swift` is generated and
excluded from both linters; nothing in this work touches it.

### Files that currently import XCResultKit

All eleven must be decoupled: `Models/TargetDevice`, `Models/Test`,
`Models/TestSummary`, `Models/Attachment`, `Models/Run`, `Models/Activity`,
`Models/Iteration`, `Models/ResultFile`, `Models/Summary`,
`Models/RunDestination`, and `Protocols/EmittableOutput`.

### The renderer is already defensive

`Activity.type`, `Activity.startTime`, `Activity.finishTime`, and
`Attachment.name` are *already* `Optional` in the existing code. Modern-backend
nils therefore degrade through code paths that already exist, rather than
needing new ones. `ParsedResult` models the lossy fields as optional and lets
that hold.

### The trap: faults must not fire on format limitations

`FaultCollector` plus `--lenient` turns degradation into exit code 3, and the
test harness asserts on the string `"Report is degraded"`. If modern-backend
nils are recorded as faults — missing attachment name, absent activity type,
absent `emittedOutput` — **every modern run exits 3 and every test fails.**

Rule: `FaultCollector` records genuine failures to read something that should
be there. It never records a field the active backend structurally cannot
provide. `Summary.validate()`'s unresolved-attachment check must distinguish
"payload export failed" from "this backend has no UTI for this attachment".

This is the single easiest way to get the migration wrong, and it fails loudly
rather than silently, so it will surface on the first modern-backend test run.

## Backend selection

`xcrun xcresulttool version` prints:

```
xcresulttool version 24514, schema version: 0.1.0 (legacy commands format version: 3.56)
```

The parenthetical is Apple's own signal that the legacy API is present; it is
expected to disappear on removal. Detection parses for it once per process and
caches. `xcresulttool help get object` also still advertises `--legacy`
("Required to enable legacy API") as a secondary signal.

An explicit override is **required**, not optional: the differential tests must
force each reader on the same bundle regardless of what the host toolchain
advertises. Exposed as a CLI option (`--result-reader legacy|modern|auto`,
default `auto`) so the harness can drive it through the existing
`xchtmlreportCmd` helper.

Any hard failure of a legacy command also demotes the backend to modern, so a
version string that changes shape unexpectedly degrades to working rather than
broken.

## Parity rules

These are the places where a naive port silently changes output.

### Status mapping

| Legacy `testStatus` | Modern `result` | `Status` |
| --- | --- | --- |
| `Success` | `Passed` | `.success` |
| `Failure` | `Failed` | `.failure` |
| `Skipped` | `Skipped` | `.skipped` |
| `Expected Failure` | `Expected Failure` | `.unknown` |

`Status` has raw values `""`, `Failure`, `Success`, `Skipped`, `Mixed`, so
`Status(rawValue: "Expected Failure")` returns nil and falls through to
`.unknown` today. The modern reader must reproduce that, not "fix" it.
Whether expected failures deserve their own status is a separate question and
explicitly **out of scope** for this work.

### Iterations — the subtle one

Legacy represents repetitions as **duplicate sibling `ActionTestMetadata`
entries sharing one identifier**, distinguished by `repetitionPolicySummary
.iteration`, which lives in the *summary* and costs an extra fetch.
`TestGroup.init` dedupes them through a `Set<TestCase>` merge.

Modern represents them as explicit `Repetition` children of the Test Case node.
Cleaner — but the parent node also carries its own `result`, and **that result
is not the same thing as the legacy status**:

```
RetryTests/testRetryOnFailure()
  legacy:  iteration 1 = Failure, iteration 2 = Success  → TestCase.status = .mixed
  modern:  Test Case result = "Passed",
             Repetition 1 = Failed, Repetition 2 = Passed
```

Taking the modern node's `result` directly yields `.success` where the report
has always shown `.mixed`. **The modern reader must derive multi-repetition
status from the repetition children and ignore the parent's `result`**, exactly
as `TestCase.iterationStatusCount()` does today.

`RetryResults.xcresult` covers this case, so it is caught by the fixture suite
rather than by users.

### Failure location

Legacy gives `fileName`, `lineNumber`, `issueType`, `message` as fields, which
`Activity.init(failureSummary:)` formats as
`"<issueType> at <file>:<line>:<message>"`. Modern gives one pre-joined string.
The modern reader populates `message` with that string and leaves
`fileName`/`lineNumber`/`issueType` nil, producing a shorter title. It does
**not** regex the file and line back out — that would build a visible UI
element on an inferred parse of a string Apple can reformat without notice.
This is a declared entry in the diff allow-list.

## `--json` becomes our own schema

`--json` is currently `exportRecursiveJson()`: a raw dump of Apple's internal
legacy object graph. It has no new-format equivalent.

`--json` will emit the `ParsedResult` model as JSON, with a documented schema,
**identically on both backends**. This is a breaking change to `--json` output
for every user, landing in 3.0 with release notes.

Rationale: the current output is Apple's internal shape and is disappearing
regardless. The break is coming either way; doing it deliberately means it
happens once, on our schedule, rather than twice and by surprise.

## Verification

The fixture suite is what makes this migration checkable, and `xcresulttool`
supporting both formats *today* is the window in which the check is possible.
That window closes when Apple removes the legacy commands, so the differential
must land with the migration, not after it.

### Reports are not byte-reproducible — measured

Rendering `SanityResults.xcresult` twice with the current binary produces **18
differing lines**, all synthetic UUIDs: `Activity.uuid`, `TestCase.uuid`,
`TestGroup.uuid`, `TestSummary.uuid`, and
`TargetDevice.uniqueIdentifier = UUID().uuidString`. After normalizing UUIDs
with a single regex, the two renders are **byte-identical**.

Any diff harness must normalize first. Without that step it reports a
difference on every run and proves nothing — precisely the class of vacuous
verification this repo has been bitten by before.

### The differential test

`Tests/XCTestHTMLReportTests/DifferentialTests.swift`, for each of
`TestResults`, `SanityResults`, `RetryResults`:

1. Render via the legacy reader and via the modern reader, forced explicitly.
2. Assert structural equality that must hold exactly:
   - per-run counts: all / passed / skipped / failed / mixed
   - the map of test identifier → status, as a set
   - the set of exported attachment filenames, and their bytes
3. Normalize UUIDs and diff the HTML. Assert the diff is empty **except** for
   the declared allow-list.

The allow-list is a checked-in file, not a fuzzy matcher. Each entry names one
known loss from the table above. A diff outside it fails the build; a diff
inside it that *stops* appearing also fails, so entries cannot rot silently
once Apple fills a gap.

Skips itself with an explicit message when the host toolchain has no legacy
support, so it never silently passes as a no-op.

### Existing suite

All 23 existing tests must stay green on both backends. Baseline confirmed
green on this branch before any work starts: `swift test` → 23 tests, 1 skipped,
0 failures.

CI runs the default (`auto`) backend. Add one job leg that forces `modern` so
both paths are exercised on every PR while legacy still exists.

## Phasing

Each phase leaves `main` shippable and green.

1. **Extract the port.** Introduce `ParsedResult` and `LegacyResultReader`;
   move the models onto `ParsedResult`. XCResultKit still present, still the
   only backend. Pure refactor — all 23 tests green, output byte-identical
   after UUID normalization. This is the largest phase and carries no
   behavioural risk, so it lands first and alone.
2. **Add the modern reader.** `XCResultToolClient`, schema structs,
   `ModernResultReader`. Reachable only through the explicit override.
3. **Differential harness.** The allow-list and `DifferentialTests`. This is
   where the migration is actually proven; it is a deliverable, not a follow-up.
4. **Backend detection and CI leg.** `auto` selection, forced-`modern` CI job.
5. **`--json` on `ParsedResult`**, release notes for the breaking change.
6. **Remove XCResultKit** from `Package.swift` and `Package.resolved`, and
   delete `LegacyResultReader` — **only once Apple removes the legacy commands.**
   Not part of this issue's work; tracked separately so the differential keeps
   running for as long as it can.

## Scope

Out of scope, deliberately:

- Any change to `HTMLTemplates.swift` or the report's visual design.
- Giving `Expected Failure` its own `Status` case.
- Reconstructing lost fields by heuristic (file:line reparsing, activity
  durations inferred from sibling `startTime`s, attachment names recovered from
  child-activity titles).
- Raising the macOS 10.15 floor or the Swift 5.5 tools version.
- Build-results, code-coverage, and insights subcommands of the new format —
  the report does not surface them. `ResultFile.getCodeCoverage()` is dead code
  today (defined, never called) and is deleted rather than ported.

## Risks

| Risk | Handling |
| --- | --- |
| Apple removes legacy before the differential lands | Phase 3 is a deliverable of this issue, not a follow-up. The window is open now. |
| New-format schema changes under us | `XCResultToolClient` pins `--schema-version` explicitly and fails loudly on an unknown version rather than mis-decoding. |
| Faults fire on format limitations → universal exit 3 | Called out above; fails loudly on the first modern test run, not silently in the field. |
| Multi-repetition status regresses `.mixed` → `.success` | Covered by `RetryResults` and by the identifier→status set assertion. |
| The diff allow-list becomes a rug to sweep regressions under | Entries are explicit and must each name a known loss; entries that stop appearing fail the build. |
