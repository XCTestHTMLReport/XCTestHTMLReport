# Cross-version comparison harness

## Problem

The repository can compare a lot of things, but not the one thing a release
decision needs: **what a user sees from this version against what they saw from
the last one.** The existing surfaces each cover a different axis:

- the CI HTML differential proves legacy-vs-modern reader parity *within* one
  version;
- `toolchain-drift.yml` proves the tool still parses what new Xcode emits, but
  says nothing about what the output looks like;
- `scripts/viewer-compare/` compares our report against *Apple's* viewer;
- the versioned Pages site archives release renders but offers no comparison
  affordance, and deliberately excludes 2.x and release candidates.

The 4.0 release candidate deliberately breaks the visual contract (#439), which
makes "did we regress anything?" unanswerable by eye across the whole surface
and unanswerable by byte-diff on principle. The 2.5.1-vs-4.0 swipe/onion
artifact built during the redesign reviews answered this question once, by
hand; nothing makes it repeatable.

## Decision

A committed, locally-run harness at `scripts/version-compare/` that renders the
same fixture bundles through pinned released binaries (2.5.1, 3.0.0, 4.0.0rc1)
plus optionally the working tree, extracts a normalized summary from each
render, and assembles a static comparison site: a semantic diff table that
flags information-level disagreements, over synced side-by-side panes for
investigating them.

**MVP axis: tool versions only.** Fixtures come from the one locally installed
Xcode. The Xcode/macOS axis arrives later by running the same stages in CI,
where runner images make toolchain selection cheap — which is why CI-readiness
is a named constraint below rather than a future hope.

## CI-readiness constraints

These hold from day one even though the MVP runs locally:

- Every stage is headless: no GUI, no prompts, no interactive auth.
- Stage outputs are files at declared paths, so a workflow can split stages
  across jobs (render needs macOS; extract and assemble run anywhere,
  including Linux).
- The site is relocatable: relative URLs only, no absolute paths baked in.
- Xcode is never hardcoded. Anything that shells out to the toolchain respects
  `DEVELOPER_DIR`, so a future CI matrix is one env var per leg.
- The run manifest records per-fixture provenance — Xcode and xcresulttool
  versions and the format stamp (via the existing
  `scripts/capture_xcresult_schema.py`), plus the bundle content hash — so
  cells produced later from different toolchains are labeled, not guessed at.
- `--strict` (exit non-zero on any failed or unexplained cell) exists from the
  start; it is the eventual CI entry point. The local default stays exit 0
  with a summary, because a human reading the site is the MVP's consumer.

## Architecture

Four stages behind one entry point, `scripts/version-compare/version_compare.sh`,
mirroring `viewer-compare`'s layout (shell orchestrator, tested Python stages):

```
acquire  → ~/.cache/xchtmlreport-version-compare/bins/<tag>/xchtmlreport
render   → <run>/render/<version>/<fixture>/          (report + stderr + exit code)
extract  → <run>/extract/<version>/<fixture>.json     (normalized summary)
assemble → <run>/site/                                (static comparison site)
```

`<run>` defaults to a UTC-timestamped directory under `/.version-compare/` at
the repository root (gitignored), mirroring viewer-compare's `/.viewer-compare`
convention. Each stage reads only the previous stage's declared output, and
each is re-runnable alone.

### CLI

```
version_compare.sh [--versions 2.5.1,3.0.0,4.0.0rc1] [--head]
                   [--fixtures TestResults,RetryResults,SanityResults,CrashResults]
                   [--run DIR] [--baseline TAG] [--serve] [--strict]
```

- `--versions` defaults to the three pinned releases.
- `--head` adds a column built from the working tree (`swift build -c
  release`), labeled `head-<shortsha>`, with `-dirty` appended when the tree
  has uncommitted changes. The everyday development loop is `--head` against
  the pinned releases.
- `--serve` starts `python3 -m http.server` on the assembled site and prints
  the URL. Serving matters beyond convenience: the panes are same-origin
  iframes that the shell injects a driver script into, which `file://` URLs do
  not reliably permit.

## Stage: acquire

Release zips are downloaded by tag via `gh release download` into the cache.
On first download the asset's sha256 is recorded next to the binary; reuse
verifies it, so a cached binary cannot rot silently and the harness works
offline once populated.

Released binaries only — old tags are never built from source. 2.x does not
build on a Swift 6 toolchain, and the shipped binary is what users actually
ran, so it is also the more honest subject.

## Stage: render

For each (version, fixture) cell:

- The fixture bundle is **copied to a per-cell temp directory** and the copy is
  rendered, never the original. At least one shipped version mutates the
  source bundle in some modes, and per-cell isolation also avoids the known
  cross-worktree temp-collision flake.
- A per-version adapter table supplies the invocation, since flags moved
  across majors (output-directory semantics changed in 4.0 via #446/#471; old
  versions take `-o`; old versions additionally get `-j` here so extraction
  has JUnit to read). All versions render self-contained output (inlined
  attachments).
- The cell records exit code, stdout/stderr, and wall time. A version that
  fails on a bundle produces a **failed cell** — that is data (it is exactly
  how "3.0 cannot read Xcode 27 bundles" will eventually manifest), not a
  harness error. The matrix always completes.

Fixtures are the four bundles `prepareTestResults.sh` generates, gated by
`scripts/verify_fixtures.sh` before any render — stale or stub fixtures are a
documented trap (#454).

## Stage: extract

One normalized shape per cell:

```json
{
  "tool": "3.0.0",
  "fixture": "RetryResults",
  "totals": {"passed": 0, "failed": 0, "skipped": 0, "expectedFailure": 0, "mixed": 0, "unknown": 0},
  "tests": [
    {"id": "SuiteName/testName()", "status": "passed", "duration": 1.23,
     "attachmentCount": 2, "failureMessages": [],
     "rawNames": ["SuiteName/testName()"]}
  ]
}
```

Sources differ by era, and neither requires new parsing machinery of any
substance:

- **4.0 and `--head`** read the tool's own `--json` output against the wire
  contract in `docs/json-schema.md`.
- **2.5.1 and 3.0.0** read the JUnit XML their `-j` flag writes
  (`report.junit`), parsed with stdlib `ElementTree`. One reader covers both
  versions, and JUnit reflects what the report *renders* — which is the
  regression question — rather than what the parser saw.

**Rejected:** scraping the old HTML (dominated by JUnit on every count), and
the old versions' `--json` flag, which emits the raw legacy xcresulttool
graph — deep, `_values`-wrapped, and precisely the parsing complexity this
harness does not need. It remains the documented upgrade path if richer
old-version data (attachment counts) is ever wanted; a scraper is never the
answer.

**Accepted cost of JUnit:** no attachment counts and coarser statuses for old
versions, so those table cells read "n/a". Attachment parity *within* 4.0 is
already byte-gated by the CI differential, and cross-version attachment
presence is visible in the panes during investigation.

**Degradation is a principle, not a fallback:** extraction is per-cell
optional. A cell whose JUnit or JSON is missing or unparseable gets a
"no data" column in the table while its rendered report still appears in the
panes. The semantic layer enriches the site; it can never block it.

**Cross-version test identity** is the one real piece of logic: joining "the
same test" across versions whose naming rules differ. The known cases are
small string normalizations (the `strippingLoneIterationNumber` parity gap is
the precedent; JUnit exhibits the documented run-reordering shape). The rules
live inside the extract stage with their own tests — deliberately not a
standalone module. Durations compare within an absolute tolerance of 0.1 s (a
named constant), never exactly: every version reads the same recorded bundle,
so a sub-tolerance difference is formatting, while a larger one means the
versions disagree about *which* duration a test has — e.g. first-run versus
last-run on a retried test — which is exactly worth flagging.

## Expected divergences

4.0 *deliberately* differs from 3.0 (renamed statuses, legacy parameterized
rendering, payload filenames — all in the 4.0 release notes). Without a
suppression mechanism the diff table highlights all of it, and highlights stop
meaning anything.

One flat checked-in file, `scripts/version-compare/expected-divergences.json`:
an array of `{pattern, reason}` entries matched against diff rows, rendered
muted with the reason on hover. Same proven shape as the CI differential's
allow-list; no version-pair scoping, no schema beyond that. It may be empty on
day one — entries accumulate as known renames surface. Anything highlighted is
by construction *unexplained*.

## Stage: assemble — the comparison site

Static files, vanilla JS, no build step, no external dependencies.

- **Landing page:** the matrix — fixtures × versions, each cell badged
  ok / failed / no-data, failed cells linking to their captured stderr.
- **Per-fixture page:** the semantic diff table on top — rows are canonical
  tests, columns are versions, with disagreements in status, presence,
  duration-beyond-tolerance, or attachment count highlighted and
  expected-divergence rows muted. The **baseline column is selectable**,
  defaulting to 3.0.0, so "what did 4.0 change" reads directly.
- **Panes below:** two or three side-by-side same-origin iframes, versions
  selectable. Sync is a generic text-search locate driven from the shell
  page, not a per-version driver: clicking a diff-table row posts the row's
  test names to each same-origin pane, and the shell page walks each
  iframe's DOM for a leaf node whose text matches one of them, expands it if
  hidden, scrolls it into view, and flashes it. This is semantic sync:
  BrowserSync's payoff without its event-mirroring fragility, which cannot
  work across three different DOMs. It is best-effort and one-directional
  (table → panes only) — a failed locate (cross-origin, template surprise)
  never breaks the table. Selection sync ships in the MVP; scroll sync only
  if selection sync proves insufficient in use.

## Error handling

- Missing `gh` or no network: a clear message; already-cached binaries keep
  every stage working offline.
- Render failure: a failed cell with stderr viewable in the site; the run
  continues.
- Extract failure: a no-data column; the run continues.
- Default exit is 0 with a one-line summary (cells ok / failed / unexplained
  diffs); `--strict` turns any failed cell or unexplained diff into a
  non-zero exit for CI.

## Testing

Discovered by the existing `lint.yml` run (`unittest discover -s scripts -p
'test_*.py'`), so tests live at `scripts/` root as
`test_version_compare_*.py`, driving each stage script as a subprocess the way
`test_viewer_compare_manifest.py` and `test_assemble_site.py` already do — the
assertions are about exit status and files on disk, not internals:

- JUnit reader and 4.0-JSON reader against small checked-in real fragments
  captured from actual 2.5.1 / 3.0.0 / 4.0.0rc1 output;
- identity-join normalization rules;
- diff computation including tolerance and expected-divergence matching;
- manifest assembly and site assembly (cell states, relative-URL property).

No full-report snapshots — those belong to the existing differential. An
end-to-end run is a manual smoke, not CI (the MVP's render stage needs Xcode
fixtures that CI's fixture cache already serves other workflows; wiring that
up is part of the deferred CI work, not the MVP).

## Out of scope (deferred, deliberately)

- The Xcode/macOS axis and the CI workflow that provides it. The constraints
  section is the down payment; the workflow is follow-up work.
- Screenshot/swipe/onion grids (the `old-vs-new-4.0` pattern) as an add-on
  view.
- Scroll sync between panes.
- Publishing the comparison site anywhere (Pages already has a decided,
  narrower contract).
- Backfilling additional 2.x versions beyond 2.5.1.
- Reading the old versions' raw-graph `--json` for attachment counts.

## Risks

- **Old binaries on new bundles.** 2.5.1 may fail outright on bundles from a
  future Xcode. That is a failed cell, which is the harness reporting reality;
  the matrix and site are built to present it, not to prevent it.
- **JUnit shape drift between 2.5.1 and 3.0.0.** Believed identical (same
  lineage); the reader's fixture fragments come from both versions so any
  divergence surfaces as a failing test during implementation, not a wrong
  table.
- **Identity-join gaps.** A join rule missed for some naming shape shows up as
  a spurious added/removed pair in the table — visible and diagnosable, not
  silent. New rules are added with tests as they surface.
- **Notarization/quarantine.** CLI-downloaded zips do not carry the quarantine
  attribute, so cached binaries run without Gatekeeper prompts; if a macOS
  change alters this, acquire grows an explicit `xattr` step.
