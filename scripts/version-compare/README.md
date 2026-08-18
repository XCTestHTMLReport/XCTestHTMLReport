# version-compare

Renders the same fixture bundles through released xchtmlreport versions
(2.5.1, 3.0.0, 4.0.0rc1 by default) and optionally this checkout, then
assembles a static site that answers: **does the new version tell the user
less than the old one did?**

Spec: `docs/superpowers/specs/2026-08-18-version-compare-harness-design.md`.

## When to run it

- Before tagging a release, with `--strict`: any unexplained diff is either a
  regression or a missing entry in `expected-divergences.json` — both need a
  decision.
- While developing, with `--head`: HEAD gets a column next to the releases.

## Usage

    ./prepareTestResults.sh          # once, or after Xcode changes
    scripts/version-compare/version_compare.sh --head --serve

Open the printed URL. The matrix page links each fixture to its comparison
page: a diff table (rows flagged where versions disagree on presence, status,
duration beyond 0.1s, or attachment count; muted rows are known divergences
with reasons on hover) over side-by-side panes of the actual reports. Click a
row to locate that test in every pane. Panes need `--serve` (same-origin
iframes); the table alone also works from `file://`.

## What each version contributes

| version | semantic source | attachment counts |
| --- | --- | --- |
| 2.5.1, 3.0.0 | `report.junit` (their `-j` flag) | n/a |
| 4.0.0rc1, `--head` | `report.json` (documented schema) | yes |

The old lineage's `--json` is the raw legacy xcresulttool graph and is
deliberately not read; JUnit reflects what those versions *render*, which is
the regression question.

## Knobs

- `--versions`, `--fixtures`, `--baseline`, `--run`: see `--help`.
- `expected-divergences.json` (this directory): `{"pattern", "reason"}`
  entries, regex-matched against `<fixture>/<test id>`. This is where known
  4.0 changes go so highlights stay meaningful.
- `XCHTMLREPORT_VC_CACHE`: binary cache location (default
  `~/.cache/xchtmlreport-version-compare`). Cached binaries are
  sha256-verified on reuse.

## Deliberately not here (yet)

The Xcode/macOS axis lives in CI later — every stage is headless and respects
`DEVELOPER_DIR`, so a workflow matrix can adopt it without changes. Also
deferred: screenshot/swipe grids, scroll sync, publishing the site.
