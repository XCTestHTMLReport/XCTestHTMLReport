# Migrating off `xcresulttool --legacy`

Design spec for [#391](https://github.com/XCTestHTMLReport/XCTestHTMLReport/issues/391). Milestone 4.0.

> Originally written against milestone 3.0, inherited from #391's label. 3.0.0
> shipped on 2026-08-07, so the breaking changes here — the `--json` schema and
> the declared output diff — land in 4.0. The migration shares that major with a
> report redesign, which is a **sibling workstream, not a follow-up release**:
> the visual contract breaks in 4.0 either way once `activityType` loses its
> data source, so breaking it once is cheaper than twice. Sequencing between the
> two is strict — migrate with templates frozen, prove the differential, then
> redesign. Changing reader and markup together makes the differential in
> "Verification" unable to attribute any diff.

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

Rows marked **dropped** were losses until the model decisions below voided them:
the field leaves the port entirely, so the legacy backend stops rendering it too
and the two backends agree by construction. Rows marked **lost** are genuine
asymmetries the differential still has to mask.

| Legacy | New format | Verdict |
| --- | --- | --- |
| activity `activityType` (5 constants driving CSS classes) | absent; only `isAssociatedWithFailure: Bool` | **dropped** (answer 2) — out of the port |
| activity `start` **and** `finish` | `startTime` only | **dropped** (answer 1) — `finish` out of the port; no duration beats a fabricated one |
| activity `uuid` | absent | synthesized locally (already how the HTML uses it) |
| attachment `name` (user-supplied, e.g. `"HTML"`) | `name` holds the legacy *filename* | **lost** — present only in a sibling child-activity title |
| attachment `filename` | `name` | maps, renamed |
| attachment `uniformTypeIdentifier` | absent | **dropped** (answer 4) — both backends type from the file extension |
| attachment `payloadRef.id` | `payloadId` | present, but payload-by-id export is itself a legacy command |
| `ActionTestFailureSummary.fileName` / `.lineNumber` / `.issueType` | one string on the `Failure Message` node: `"RetryTests.swift:31: XCTAssertTrue failed"` | **lost as structure**, text preserved |
| log section `emittedOutput` | absent; structured `messages` instead | **lost** |
| `exportRecursiveJson()` (drives `--json`) | no equivalent | **no replacement** |
| repetitions (duplicate siblings + `repetitionPolicySummary`) | first-class `nodeType: "Repetition"` | **improved** |
| Swift Testing `Arguments` / `Expression` / `Test Value` | first-class node types | **modern-only** (answer 6) — slot added now, unexercised by fixtures |
| tree shape | two fewer wrapper levels | differs, see below |

Consequence: byte-identical output across the two backends is not achievable.
The bar is a *declared and reviewed* diff, asserted in CI, not an empty one —
though the model decisions shrink what has to be declared from five entries to
three, which makes the remaining diff a stronger proof than a larger masked one.

### Tree shape

```text
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

```text
Sources/XCTestHTMLReportCore/Classes/ResultReading/
  ParsedResult.swift                backend-neutral model (the port)
  ResultReader.swift                protocol: read() -> ParsedResult?
  ResultBackend.swift               detection + override
  Legacy/LegacyResultReader.swift   XCResultKit  → ParsedResult
  Modern/ModernResultReader.swift   xcresulttool → ParsedResult
  Modern/XCResultToolClient.swift   subprocess + JSON decode, schema-version pinned
  Modern/TestResultsSchema.swift    Codable structs for the new format
```

`Classes/Models/*` stop importing XCResultKit and build from `ParsedResult`.
This is the only shape in which dual-path does not duplicate the renderer.

`read()` returns an optional rather than throwing, mirroring the existing
`getInvocationRecord()` contract that `Summary.init` already guards with a
`.missingInvocationRecord` fault. A nil read is therefore reported, not
swallowed. Failures *below* the top level are the ones that need care: a failed
activities query returns an empty list, which without a fault would render a
visibly gutted report and still exit 0. That path records
`.missingActivities`.

**HTML templates do not change.** Nothing in this work touches
`HTMLTemplates.swift`.

Correcting the premise, because it is wrong and it matters later: that file is
*not* generated. Its header says `DO NOT EDIT! This file is autogenerated by
createTemplates.sh`, and both `.swiftformat` and `.swiftlint.yml` exempt it on
that basis — but `createTemplates.sh` was deleted in #295 ("remove ruby & thor
tasks") and nothing has regenerated it since. `HTMLTemplates.swift` is the real,
hand-maintained source; `Sources/XCTestHTMLReportCore/HTML/*.html` is a stale
copy excluded from the build, now 28 diff hunks behind (875 vs 764 non-blank
lines in `index.html`). #349 hand-edited the "generated" file on 2024-01-23, one
day after #350 last touched the supposed source.

No consequence for this work, which does not touch either. It is a live trap for
the redesign workstream, which must pick one source of truth first.

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

```text
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

Demotion is scoped to **capability detection only**. `auto` and an explicit
`legacy` both fall back to `modern` when the toolchain does not advertise the
legacy commands, so a version string that changes shape unexpectedly degrades
to working rather than broken.

It is deliberately **not** "any hard failure of a legacy command demotes".
A corrupt bundle, a permission error, a truncated `.xcresult`, or a subprocess
that dies for an unrelated reason are not evidence that legacy support is
gone — and silently retrying them on the modern reader would replace a clear
failure with a partial report that looks fine. Those failures propagate through
`FaultCollector` (`.missingInvocationRecord`, `.missingActivities`,
`.payloadExportFailed`) and reach the exit-3 path, exactly as they would if
only one backend existed.

## Deciding the model before the port

`ParsedResult` is the one artifact this migration could end up building twice.
Shaped so the current templates render unchanged, it is not backend-neutral —
it is legacy-shaped, and the modern reader spends its life supplying `nil` for
fields that exist only because the old UI reads them.

The redesign's *visual* work is a sibling workstream and does not gate this one.
Its **information model** does, because that is what the port encodes. So a
bounded set of questions gets answered before Task 3 writes the model:
per-activity durations, activity types, `ObjectClass`, attachment typing, status
representation, Swift Testing arguments, insights and metrics, and whether
test-case duration sums repetitions.

Direction of the win: each answer either removes a field from the port or an
entry from the differential allow-list. Deliberately holding the legacy backend
down to the modern backend's capability makes the two agree, and an unmasked
diff proves more than a masked one. The cost is one-way and honest — the legacy
backend stops rendering some things it could have — but it is a 4.0 behaviour
change made once and visible in the model, rather than a permanent asymmetry
hidden behind a mask.

**Task 2.5 of the implementation plan carries the questions and the reasoning
behind each answer. The answers themselves are recorded below**, and Task 3 and
Task 12 are read against this record rather than against the plan.

### The answers

| # | Question | Answer | Rationale |
| --- | --- | --- | --- |
| 1 | Per-activity durations? | **No** — drop `ParsedActivity.finish` | Modern publishes `startTime` only; no duration beats a fabricated `(0.00s)`. Voids the `durations` allow-list entry. |
| 2 | The five activity-type states? | **No** — drop `ParsedActivity.activityType`, keep `isFailure` | The one genuinely useful state (`userCreated`) has no modern source at any fidelity, and a field only one backend can populate is the anti-pattern this exercise exists to catch. Voids `activityTypeClasses`. |
| 3 | `ObjectClass` in the model? | **No** — Task 5 deletes the type | `IDESchemeActionTestSummaryGroup` is an Xcode internal class name rendered into a CSS class. No modern equivalent and no reason to acquire one. |
| 4 | Attachment UTI as its own field? | **No** — `filenameExtension` only, both backends | `AttachmentType` needs only enough to pick a template and a MIME type. Legacy maps its UTI down to an extension, and attachment typing becomes identical rather than allow-listed. |
| 5 | Status as a legacy raw string? | **No** — neutral enum, both readers map into it | `statusRawValue: String` would make the modern reader emit legacy spellings it never saw. Fabricating legacy shape is the line this exercise draws. |
| 6 | Swift Testing `Arguments`? | **Yes, now** — `ParsedTestCase.arguments: [String]` | The only addition that is *inside* the tree; adding the slot later means reshaping the port. Empty on legacy and for non-parameterized tests. |
| 7 | Insights / metrics? | **No, not now** | Separate documents from separate subcommands, attaching beside `runs` at the top level. Additive later is cheap and local; no empty slots now. |
| 8 | Test-case duration sums repetitions? | **Yes** — keep today's behaviour | The modern Test Case node reports its own duration, which is not the sum (measured on `RetryResults`: `testJustFail()` reports 0.065s against repetitions of 0.063s and 0.068s). Summing in the renderer makes both backends agree by construction. |

Net effect on the port: three fields removed (`finish`, `activityType`,
`uniformTypeIdentifier`), one field added (`arguments`), one field retyped
(`statusRawValue` → enum), one existing type deleted (`ObjectClass`).

Net effect on the differential: the allow-list drops from five entries to
three. Naming them, since this record is what Task 12 is read against —
`activityTypeClasses` and `durations` are **deleted**, because with no field in
the port there is no divergence to mask:

| Rule | What still differs | Exercised by |
| --- | --- | --- |
| `attachmentDisplayNames` | Modern exposes only the generated filename, so display names fall back to the type-derived label (`Screenshot`, `Video`, `File`). No modern source for the user-supplied name. | `TestResults` — `FirstSuite/testWithSpecialChars()` and `testAttachHtmlData()` both set `XCTAttachment.name` |
| `failureTitlePrefix` | Legacy renders `<issueType> at <file>:<line>:<message>`; modern's `Failure Message` node gives `<file>:<line>: <message>` pre-joined, with no `issueType`. | `TestResults` — every failing case; `RetryResults` — `testJustFail()` |
| `wrapperGroups` | Modern omits the legacy `Selected tests` / `All tests` and `<target>.xctest` levels. A deliberate render difference, not a format loss. | `TestResults` — both bundles; `SanityResults` |

Everything outside these three must be byte-identical after masking. An
addition to this table is a design decision requiring a written justification,
not a way to quiet a failing differential — and the preferred move is always to
delete the field from the port instead, as answers 1, 2, and 4 did.

**Answer 6 is not exercised by any fixture.** The authoritative `TestNodeType`
enum — `xcresulttool get test-results tests --schema` — lists `Arguments`,
`Expression`, and `Test Value`, but `SwiftTestingSuite` has no
`@Test(arguments:)` case, and all three bundles contain zero `Arguments` nodes.
The field is therefore added on the strength of the published schema, not
observed data. The plan adds a parameterized `@Test` to the sample app so the
slot is populated by something real; until that lands, treat `arguments` as
unverified rather than working.

**Answer 4 has a platform constraint.** `UTType(filenameExtension:)` is macOS 11+
and the floor here is 10.15, so the extension→type mapping cannot rely on it
alone. `Attachment.swift` already guards `UTType` behind
`if #available(macOS 11.0, *)` with a hardcoded fallback; the extension mapping
follows the same shape.

Non-negotiable regardless of how the answers land: **no reader code whose only
purpose is to satisfy the render-level diff.** If `ModernResultReader` is ever
tempted to fabricate an `activityType`, the port is wrong, not the reader. The
current templates are a verification scaffold with a retirement date, not a
compatibility target.

## Parity rules

These are the places where a naive port silently changes output.

### Status mapping

Under answer 5 the port carries a neutral `ParsedStatus`, and this table is the
definition of **both** readers' mappings rather than a note about one. Neither
reader emits the other's spelling.

| Legacy `testStatus` | Modern `result` | `ParsedStatus` | Renders as `Status` |
| --- | --- | --- | --- |
| `Success` | `Passed` | `.passed` | `.success` |
| `Failure` | `Failed` | `.failed` | `.failure` |
| `Skipped` | `Skipped` | `.skipped` | `.skipped` |
| `Expected Failure` | `Expected Failure` | `.expectedFailure` | `.unknown` |
| *(anything else)* | `unknown` | `.unknown` | `.unknown` |

The modern `TestResult` enum is `Passed`, `Failed`, `Skipped`,
`Expected Failure`, `unknown` — taken from
`xcresulttool get test-results tests --schema`, not inferred from the fixtures,
which never produce `unknown`.

`.expectedFailure` renders as `Status.unknown` because `Status` has raw values
`""`, `Failure`, `Success`, `Skipped`, `Mixed` and no case for it, so
`Status(rawValue: "Expected Failure")` returns nil today. Both readers must
reproduce that, not "fix" it. Giving expected failures their own status is a
separate question, explicitly **out of scope** — but note the model now names
the state even though the renderer flattens it, so the redesign can act on it
without another port change.

### Iterations — the subtle one

Legacy represents repetitions as **duplicate sibling `ActionTestMetadata`
entries sharing one identifier**, distinguished by `repetitionPolicySummary
.iteration`, which lives in the *summary* and costs an extra fetch.
`TestGroup.init` dedupes them through a `Set<TestCase>` merge.

Modern represents them as explicit `Repetition` children of the Test Case node.
Cleaner — but the parent node also carries its own `result`, and **that result
is not the same thing as the legacy status**:

```text
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

**Which document that string comes from matters.** The two sources are not
equivalent — measured on `TestResults`:

| Source | `FirstSuite/testTwo()` failure text |
| --- | --- |
| `get test-results tests`, `Failure Message` node | `FirstSuite.swift:66: XCTAssertTrue failed - Test failed` |
| `get test-results activities`, activity title | `XCTAssertTrue failed - Test failed` |

The activities document drops the file and line entirely. The modern reader
therefore sources failure text from the `Failure Message` nodes, which retain
it, and appends those to the activity list. Skipped tests carry their reason on
the same node (`Test skipped - Test skipped`).

What remains lost is the *structure*: the reader populates the title with the
string as given and leaves `fileName`/`lineNumber`/`issueType` nil rather than
regexing them back out, since that would build visible UI on an inferred parse
of a format Apple can reformat without notice. The residual difference — legacy
renders `Assertion Failure at FirstSuite.swift:66:...`, modern renders
`FirstSuite.swift:66: ...` — is a declared entry in the diff allow-list.

## `--json` becomes our own schema

`--json` is currently `exportRecursiveJson()`: a raw dump of Apple's internal
legacy object graph. It has no new-format equivalent.

`--json` will emit the `ParsedResult` model as JSON, with a documented schema,
**identically on both backends**. This is a breaking change to `--json` output
for every user, landing in 4.0 with release notes.

Rationale: the current output is Apple's internal shape and is disappearing
regardless. The break is coming either way; doing it deliberately means it
happens once, on our schedule, rather than twice and by surprise.

**`ParsedResult` is an internal Swift model, not a wire contract.** Deriving
`--json` from it with a synthesized `Encodable` would publish whatever the type
happens to look like on the day, and every later field rename would be a silent
breaking change to a public output. Task 14 must therefore write the contract
down before it ships, covering at minimum:

- field names and nesting, with a complete worked example from a real fixture
- enum encoding (`ParsedStatus` as lowercase strings, not ordinals)
- null versus omitted for every optional — one rule, applied uniformly
- duration units (seconds as a JSON number) and timestamp format
- array ordering guarantees, so consumers can diff two reports
- a top-level schema version, and what a consumer should do when it changes

Until that exists the `--json` change is specified only as "our schema", which
is not a contract anyone can build against. This is a Task 14 deliverable, not
a follow-up: the flag is public output, and #391 is where it changes.

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

#### This is #411, and #430 already fixes it

The above rediscovered [#411](https://github.com/XCTestHTMLReport/XCTestHTMLReport/issues/411)
independently. [PR #430](https://github.com/XCTestHTMLReport/XCTestHTMLReport/pull/430)
fixes it *in the product* rather than in the harness: identifiers become a
digest of each element's structural path via `IdentifierPath`, rendered as
lowercase `[0-9a-f]{32}`. It also fixes two further drift sources the UUID work
alone did not — per-status counts read out of a `Dictionary`, and `Set` iteration
plus non-total sort comparators. **This migration rebases onto #430 rather than
building its own normalization.**

**#430 does not retire the normalizer, and assuming it does breaks the
differential.** Post-#430 identifiers are deterministic *for a given structural
path*, and the two backends do not agree on structure — the modern tree drops
the `"All tests"` and `"<bundle>.xctest"` wrapper levels (see "Tree shape"), so
the same test case sits at a different path under each backend and digests to a
different value. Cross-backend identifier divergence therefore survives #430
intact.

What changes is what the normalizer matches:

| | Before #430 | After #430 |
| --- | --- | --- |
| Identifier form | uppercase RFC-4122 UUID | lowercase `[0-9a-f]{32}` |
| Same-backend, two renders | differs — normalizer required | **identical** — normalizer not required |
| Legacy vs modern render | differs | **still differs** — normalizer required |

Consequence for the harness: the same-backend reproducibility pin becomes an
assertion of exact equality with no normalization (which is a stronger pin than
the one this spec originally proposed), while the cross-backend differential
still normalizes — against the hex-digest pattern, not the UUID one. A regex
written for RFC-4122 silently matches nothing after #430 and the differential
degrades to comparing raw identifiers, which fails on every run.

### The differential test

`Tests/XCTestHTMLReportTests/DifferentialTests.swift`, for each of
`TestResults`, `SanityResults`, `RetryResults`:

1. Render via the legacy reader and via the modern reader, forced explicitly.
2. Assert structural equality that must hold exactly:
   - per-run counts: all / passed / skipped / failed / mixed
   - the map of test identifier → status, as a set
   - the set of exported attachment filenames, and their bytes
3. Normalize identifier digests and diff the HTML. Assert the diff is empty **except** for
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

0. **Prerequisite: #430 — merged 2026-08-11 (`a28b131`).** Deterministic
   identifiers are not a nice-to-have for this work: without them the
   differential in phase 3 cannot distinguish a reader regression from ordinary
   identifier churn, and the phase-1 "output byte-identical" gate is unusable.
   Satisfied; branch from a `main` at or after that commit.
0b. **Settle the information model** before `ParsedResult` is written. See
   "Deciding the model before the port" below.
1. **Extract the port.** Introduce `ParsedResult` and `LegacyResultReader`;
   move the models onto `ParsedResult`. XCResultKit still present, still the
   only backend. Pure refactor — all 23 tests green, output byte-identical
   with **no** normalization applied, which #430 makes achievable and which is a
   stronger gate than the normalized comparison originally planned here: a
   refactor that perturbed the tree would move `IdentifierPath` digests, and
   normalizing would hide it. This is the largest phase and carries no
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

- Any change to `HTMLTemplates.swift` or the report's visual design. The
  redesign is a **sibling 4.0 workstream** that runs after this one, not a later
  release — see the note at the top. Holding the markup still is what makes the
  differential able to attribute a diff to the reader change.
- Giving `Expected Failure` its own `Status` case.
- Reconstructing lost fields by heuristic (file:line reparsing, activity
  durations inferred from sibling `startTime`s, attachment names recovered from
  child-activity titles).
- Raising the macOS 10.15 floor or the Swift 5.5 tools version.
- Multi-destination result bundles. `prepareTestResults.sh` boots one
  simulator, so no fixture exercises more than one destination. The modern
  reader emits one run per reported device, matching legacy's
  one-run-per-`ActionRecord`, but that mapping is written from the format and
  **not verified against a two-destination bundle**. The differential asserts
  run-count parity so a divergence fails loudly; that is the most the current
  fixtures allow, and the path should not be described as tested.
- Subprocess timeouts. Neither backend bounds how long `xcresulttool` may run;
  XCResultKit does not either, so this is not a regression. A hang would hang
  the tool. Worth its own issue rather than being folded in here.
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
| Normalizer written for UUIDs silently matches nothing after #430 | The cross-backend differential must target `[0-9a-f]{32}`. A no-op normalizer fails loudly (identifiers differ on every run), not silently, but the cause is easy to misdiagnose. |
| Redesign lands concurrently and the differential can no longer attribute a diff | Templates are frozen for the whole of this work; the redesign is sequenced after phase 3. |
