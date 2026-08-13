# Test coverage for the rendered report

## Problem

Nothing in this repository has ever asserted anything about how the report
*looks*, and until 2026-08-13 nothing had even rendered one in a browser.

The suite compares report HTML as text and nothing else:

- `DifferentialTests` — legacy reader output against modern reader output.
- `ReproducibilityTests` — one backend against itself across runs.
- `BaselineCaptureTests` — a before/after capture harness, driven by hand.

Every one of those compares a render to *another render*. None of them knows
what any of it means. A stylesheet change that resolves a token to nothing, a
dark-mode palette that fails contrast, a filter tab that stops filtering, an
`aria-` attribute that disappears — all pass, silently, because the text
still differs from the other reader in exactly the declared ways.

This is now load-bearing. #439 is redesigning the report UI in 4.0. Its first
part, #455, tokenized the stylesheet into 33 CSS custom properties and
claimed "zero visual change" — a claim no test could confirm and no reviewer
had checked in a browser. Its second part, #456, adds dark mode and asserts
WCAG contrast floors. Those are precisely the claims a browser can verify
mechanically and a human reviewer cannot.

## Decision

Build coverage in three layers, bottom-up, over one synthetic fixture:

1. **Unit** — model logic, at source.
2. **Snapshot** — per-template HTML goldens.
3. **Browser** — computed styles, contrast, dark mode, a11y, behaviour.

Layers 1 and 2 are Swift and add no new toolchain. Layer 3 introduces
Playwright, scoped strictly to facts only a browser knows.

The suite lands *before* #456, which then rebases on top and becomes its
first real subject.

## The constraint that shapes everything

`BaselineCaptureTests.swift` already states it:

> Fixtures are regenerated on each `prepareTestResults.sh` run, so a golden
> file cannot be checked in; capture before a refactor and again after,
> against one fixture generation, then diff the two directories.

**A golden keyed to a generated `.xcresult` drifts with the fixture, not with
the code.** That rules out the obvious design — commit `index.html`, diff it
on every PR — and it is why the existing harness is a two-run capture rather
than a checked-in file.

The way out is to stop feeding renders from generated fixtures. A golden
whose inputs are hand-written constants is stable by construction, and that
is what Layer 2 uses.

## What the code already gives us

Verified against `main` at `f3f960f`:

- **`ParsedResult` and its whole tree are `public`.** `ParsedRun`,
  `ParsedTestCase`, `ParsedActivity`, `ParsedAttachment` and the rest are
  plain structs, constructible directly from a test. #391 introduced them as
  the documented contract between reading and rendering, which makes the
  boundary between "read an `.xcresult`" and "render HTML" already a seam.
- **`Run.init?` takes a `ParsedRun`.** Templates below the page level render
  without any `.xcresult` at all.
- **`PayloadProviding` is a five-member protocol** — `url`,
  `exportPayload`, `exportPayloadData`, `exportLogs`, `exportLogsData`.
  Trivially stubbable; the test target already uses `@testable import`.
- **All 20 test files use XCTest.** swift-testing appears only inside the
  sample app, as fixture material. New tests use XCTest.
- **`ParsedResult` has no `Decodable` conformance.** The fixture is therefore
  Swift, not JSON. See Risks.

### The one production change

`Summary`'s only public initialiser takes `resultPaths: [String]` and does
the reading internally. There is no way to hand it a `ParsedResult`.

Add an initialiser that accepts pre-parsed runs:

```swift
public init(
    parsedRuns: [ParsedRun],
    renderingMode: RenderingMode,
    downsizeImagesEnabled: Bool,
    downsizeScaleFactor: CGFloat,
    faultCollector: FaultCollector = FaultCollector()
)
```

This injects at the boundary #391 already created; it is not a testing
back door bolted onto an unrelated type. Without it, snapshots reach 13 of
the 14 `HTMLTemplates` members but never `index` — the full page, which is
where the stylesheet and the token layer live, and therefore the only place
the redesign can be observed.

## Architecture

### The shared fixture

`Tests/XCTestHTMLReportTests/Synthetic/SyntheticResult.swift` builds one
`ParsedResult` covering the states that render differently:

- passed, failed, skipped, `expectedFailure`
- a test with retries (multiple iterations)
- nested sub-activities
- one attachment of each rendered kind: PNG, video, plain text, HTML, and an
  attachment whose filename contains quotes and angle brackets

`Synthetic/StubPayloadProvider.swift` implements `PayloadProviding` and
returns fixed constants — a 1×1 PNG and a short text blob. **No binary
fixture files enter the repository**, and the payloads are identical on every
machine and every run.

This one fixture feeds all three layers. That is the point: the layers
disagree about what they assert, never about what they are looking at.

### Layer 1 — unit tests

Model logic, no HTML. The first case is a real defect this work already
found:

`TestScreenshotFlow.init?(activities:tailCount:)` declares
`tailCount _: Int = 3` — the parameter is discarded — and the body hardcodes
`.suffix(3)`. Passing `tailCount: 5` silently yields 3. The only caller,
`Iteration.swift:26`, never passes it, so nothing has ever noticed.

Written RED first: assert `tailCount: 5` yields five, watch it fail, then fix
the source. Further cases cover activity-type states and the tail/flow
class-name split (`screenshot-flow` vs `screenshot-tail`).

### Layer 2 — template snapshots

`TemplateSnapshotTests` renders each `HTMLTemplates` member against the
synthetic fixture and compares committed goldens in
`Tests/XCTestHTMLReportTests/Snapshots/*.html`.

Stable because the inputs are constants. Fast because there is no simulator
and no `.xcresult` — fixture generation currently dominates the test job's
wall time (#412), and this layer skips it entirely.

Goldens refresh with `XCHR_UPDATE_SNAPSHOTS=1`, mirroring the existing
`XCHR_BASELINE_DIR` idiom rather than inventing a second convention. A
refreshed golden shows up as a reviewable diff in the PR, which is the
mechanism by which "this changed" becomes visible.

### Layer 3 — browser assertions

`visual/` at the repository root: `package.json`, `package-lock.json`,
`playwright.config.ts`, `tests/*.spec.ts`. Deliberately outside `Tests/`, so
SwiftPM does not try to interpret it as target sources.

A dump test writes the rendered synthetic report to `$XCHR_VISUAL_DIR` —
again the `BaselineCaptureTests` idiom. Playwright loads it over `file://`,
which it supports natively. No server, no `.xcresult`, no simulator.

**Gating assertions**, all deterministic:

1. **Token resolution** — every custom property declared on `:root` resolves
   to a non-empty computed value, and no rule references an undeclared token.
   This is exactly #455's failure mode.
2. **Contrast** — WCAG ratios computed from resolved token values;
   ≥ 4.5:1 normal text, ≥ 3.0:1 large. The pairings are **discovered from
   the stylesheet**, not hand-listed: for each rule that sets a
   `--color-text-*` token, the effective background token is resolved from
   its cascade. A hand-maintained matrix would silently stop covering a
   pairing the moment the redesign introduced one.
3. **Dark mode** — assertions 1 and 2 re-run under `colorScheme: 'dark'`.
   Asserts the tokens actually change *and* still clear the floors.
4. **axe-core** — zero violations at `critical` and `serious`. `moderate`
   and `minor` are reported in the job summary but do not gate. This
   mechanizes the template accessibility pass left open by #440.
5. **Behaviour** — filter tabs change which rows are visible; arrow keys move
   selection; clicking an attachment populates the preview pane. Real
   regressions that no static comparison catches.

**Explicitly not done: pixel diffing.** Screenshots are captured and uploaded
as review artifacts, never compared. Pixel baselines are flaky across
renderer versions and committing PNGs bloats the repository; assertions 1–4
capture the same intent as numbers, which do not drift when Chromium changes
a font hinter.

## CI shape

Mirrors `pages.yml`, which established the pattern on 2026-08-13:

- **macOS job** — `swift test` (Layers 1 and 2 gate here), then dump the
  synthetic report and upload it as an artifact.
- **ubuntu job** — download the artifact, `npm ci`, `npx playwright test`.
  Browsers install quickly on Linux and the expensive runner stays out of it.

Actions pinned by SHA, `persist-credentials: false`, explicit minimal
`permissions` — `zizmor --min-severity low` gates `.github/workflows/` and
will audit any new file. `node_modules/` is gitignored; the lockfile is
committed and `npm ci` is used so the browser layer cannot drift silently.

## The retroactive baseline

Three capture points, using `BaselineCaptureTests`, which **already exists at
all three commits** — no back-porting the new suite:

| commit | state |
|---|---|
| `72816c4` | pre-tokenization |
| `fdbe78b` | post-tokenization, pre-theme |
| #456 head | post-theme |

The subtlety, from the harness's own header: all captures must run against
**one fixture generation**. Generate once, then build each commit and capture
without regenerating in between. Fixtures are gitignored, so checking out a
different commit does not disturb them.

`diff -r` across the first two either confirms or refutes #455's "zero visual
change" claim, retroactively.

Then the useful part: **Layer 3 consumes HTML files, not builds.** Once it
exists, the same contrast, dark-mode and axe assertions point at all three
historical captures. The browser layer is version-agnostic, so the redesign
gets a real audit trail rather than only a forward-looking gate.

## Sequencing

1. This suite lands on `main`.
2. #456 rebases onto it. Its PR run is the first real subject: dark mode and
   the WCAG floors verified by machine before merge.
3. The retroactive capture runs as a one-off and its findings are recorded on
   #439 and #455.

Step 2 is the reason for the ordering. Landing #456 first would ship its
central claims unverified and reduce this suite to describing whatever
shipped.

## Phasing

Three phases, each independently mergeable and each leaving the tree green:

1. **Swift foundation** — the `Summary` seam, the synthetic fixture, the stub
   payload provider, Layer 1 unit tests, and the `tailCount` fix. No CI
   change; the existing test job picks these up.
2. **Snapshots** — Layer 2 plus its committed goldens and the
   `XCHR_UPDATE_SNAPSHOTS` refresh path.
3. **Browser** — `visual/`, the dump test, the Playwright assertions, and the
   two-job CI wiring.

The retroactive capture is a one-off that runs after phase 3 and produces
findings, not code.

## Verification

The suite is doing its job when:

- The `tailCount` test fails before the fix and passes after.
- Deliberately breaking a token reference in `HTMLTemplates.swift` fails
  Layer 3 assertion 1 — confirmed by trying it, not assumed.
- Deliberately darkening `--color-text-muted` past the floor fails
  assertion 2.
- Layers 1 and 2 run with no simulator and no `.xcresult` present. Verified by
  parking only the three `.xcresult` bundles: `Package.swift` also declares
  `Resources/differential-allowlist.json`, and SwiftPM synthesizes
  `Bundle.module` — which `TestSupport.swift` references unconditionally — only
  when at least one declared resource resolves. Removing the whole `Resources`
  directory therefore breaks the test target's build for a packaging reason
  unrelated to these tests.
- The retroactive diff produces a definite verdict on #455 either way. "No
  output" is a failed capture, not a pass — the harness header already warns
  that `diff -r` reports two partial directories as identical.

## Scope

**In:** the three layers, the `Summary` seam, the CI wiring, the one-off
retroactive capture, and the `tailCount` fix that Layer 1 surfaces.

**Out:**

- Pixel-diff gating.
- Fixing whatever axe-core finds. The a11y *pass* is #440's work; this spec
  only makes violations visible and gates against new ones. If the templates
  already violate at `critical` or `serious` on day one, those findings are
  filed onto #440 and the gate narrows to `critical` only until #440 clears
  them — a narrowing recorded in the plan, never a silent `continue-on-error`.
- Replacing `DifferentialTests` or `ReproducibilityTests`. They answer a
  different question — reader parity — and stay.
- Any redesign decision. This spec asserts claims; it does not make them.

## Risks

**Synthetic drift.** The fixture is hand-written, so it can stop resembling
what real `.xcresult`s produce. Mitigation: the existing real-fixture tests
stay, and both are rendered by one code path — a divergence shows up as a
differential failure, not as silence.

**Day-one axe failures.** Likely, since the a11y pass has not happened. See
Scope: gate at the currently-clean severity, triage the rest to #440.

**Node in a Swift repository.** New toolchain, new supply chain. Mitigated by
`npm ci` against a committed lockfile, a pinned Playwright version, and
confinement to `visual/`. The Swift build and the existing test job never
depend on it.

**Fixture regeneration during the retroactive capture.** Would silently
invalidate the comparison. The capture is a documented one-off sequence, and
the verification criterion above treats an empty diff with suspicion rather
than as a pass.

**`ParsedResult` gains `Decodable` later.** Not a risk so much as a deferred
improvement: the fixture could then move to a committed JSON file and double
as executable documentation of the wire contract in `docs/json-schema.md`.
The Swift fixture is a deliberate first step, not a permanent choice.
