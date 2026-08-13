# Versioned demo reports on GitHub Pages

## Problem

`pages.yml` publishes one rendered report to
`https://xctesthtmlreport.github.io/XCTestHTMLReport/` on every merge to `main`,
replacing whatever was there. The site therefore only ever answers "what does
the report look like right now."

It cannot answer "what did the report look like in 3.0" — a question that has
practical weight, because 4.0 deliberately breaks the report's visual contract
(#439) and because the tool's users are running released versions, not `main`.

## Decision

Publish release renders alongside `main`'s under versioned paths:

```
/                    main, republished on every merge (unchanged behaviour)
/v/3.1.0/            a stable release, written once, never rewritten
/v/index.html        generated listing
```

Stable releases only. Forward-only — no backfill of 2.x or 3.0.0.

## The constraint that shapes everything

`actions/deploy-pages` **replaces the entire site** on each deployment. There is
no incremental publish. Every deploy must therefore upload `main`'s render *and*
every version, which means versions have to persist somewhere outside the run.

Measured, not assumed:

| quantity | value |
|---|---|
| current live site | **11,096,947 bytes** (rendered `-i`, attachments inlined) |
| commits to `main` | **48 in 90 days** ≈ 190/year |
| stable releases | ~2–4/year |
| Pages site limit | 1 GB |

Per-*commit* versioning was considered and rejected on this arithmetic:
11.1 MB × 190/year ≈ **2.1 GB/year**, exceeding the Pages limit within about six
months. The bulk is four `.mp4` screen recordings at ~1.5 MB each, which `-z`
image downsizing does not touch. Per-*release* versioning costs ~44 MB/year.

## Prerequisite: the `github-pages` environment must permit tag refs

**This blocks the release path and requires a maintainer settings change.**

The `github-pages` environment carries a deployment branch policy admitting
exactly one ref: the branch `main`. A workflow triggered by a tag push runs with
`ref = refs/tags/<tag>`, so `deploy-pages` from that run is rejected by the
protection rule.

The fix is to add a **tag** policy entry alongside the existing branch entry,
matching the stable release pattern. Until that exists, `pages-release.yml`
cannot deploy and the versioned paths will never appear.

Working around it instead — having the release workflow signal a `main`-ref run
to do the deploy — is not viable: workflow runs triggered by `GITHUB_TOKEN` do
not themselves trigger further workflow runs, so the chain breaks silently.

## Architecture

### The version store

A `pages-site` branch holds **only** immutable version renders:

```
v/3.1.0/index.html
versions.json        ["3.2.0", "3.1.0"] — newest first
```

`versions.json` is a flat array of tag strings in descending release order. It
is the declared inventory the truncation guard checks the assembled site
against, and the input the listing page is generated from — so the two can never
disagree about what is published.

`main`'s render is deliberately **not** stored. It changes on every merge and is
cheap to regenerate, so storing it would mean writing 11 MB to a branch 190
times a year — either bloating git history permanently or forcing an orphan
force-push whose object reuse degrades after garbage collection.

Keeping the store immutable is what allows the frequent path to be read-only.

### `pages.yml` (modified)

Triggers: `push` to `main`, `workflow_dispatch`, and a new `workflow_call` so the
release workflow can reuse it.

- **`build`** (macOS, `contents: read`) — checkout `main`; checkout `pages-site`
  into `_site/`; **delete `_site/.git`**; build the release binary; render `main`
  into `_site/index.html`; generate `_site/v/index.html`; upload the Pages
  artifact.

  The `.git` deletion is not incidental. `actions/checkout` with `path: _site`
  leaves a full repository there, and `upload-pages-artifact` packages whatever
  it is given — so without the deletion every deploy publishes the store's git
  history as browsable files.
- **`deploy`** (ubuntu, `pages: write`, `id-token: write`) — unchanged.

**No write permission anywhere in this path**, which is the design's main
security property: the workflow that runs 190 times a year only reads.

### `pages-release.yml` (new)

Trigger: `push` to tags matching `[0-9]+.[0-9]+.[0-9]+`.

Stable-only filtering falls out of the glob at no cost. `release.yml` already
requires two separate patterns — `[0-9]+.[0-9]+.[0-9]+` and
`[0-9]+.[0-9]+.[0-9]+rc[0-9]+` — which is direct evidence the first does not
match `3.0.0rc1`.

- **`publish-version`** (macOS, `contents: write`) — checkout the tag, build,
  render, write `v/<tag>/index.html` into `pages-site`, update `versions.json`,
  push.
- **`deploy`** — `uses: ./.github/workflows/pages.yml`, so assembly and
  deployment exist in one place rather than two.

`contents: write` appears in exactly one job, on a path that runs a few times a
year. This mirrors `release.yml`, which already declares permissions per job
rather than at workflow level, with a comment explaining why.

## Guards

Each of these prevents a **green build that loses data** — the failure mode that
motivated rejecting the alternative designs.

1. **Truncation guard.** After assembly, count `_site/v/*` against
   `versions.json`. Fewer than declared fails the run. Without it, a version
   silently disappearing from a deploy looks like success.
2. **Size guard.** Fail if `_site` exceeds 800 MB, so the ceiling arrives as a
   CI failure with headroom rather than a Pages rejection at 1 GB.
3. **Idempotency.** Re-running a tag overwrites `v/<tag>/` rather than appending,
   so a re-run cannot corrupt the store.
4. **Bootstrap.** `pages-site` is created during implementation carrying
   `versions.json` as `[]`, so the first `pages.yml` run does not fail checking
   out a branch that does not exist.

## Discoverability

`/v/index.html` is generated at assembly time from `versions.json`: a minimal
static page listing each published version newest-first, each linking to
`./<tag>/`. No styling beyond what keeps it legible, and no dependency on the
report templates. The README gains a line pointing at it.

A version switcher *inside* each report was rejected: it would require
post-processing the rendered HTML, which is invasive and would churn the
committed golden snapshots on every template change. The listing touches
nothing.

## Alternatives rejected

**Reconstruct from the live site.** Fetch `versions.json` from the published
site, re-download each version, add the new one, re-upload. Needs no branch and
no write permission — genuinely attractive. Rejected because a 404 or a brief
outage drops a version from the next deploy while the run still reports success.

**Re-render every version on every deploy.** Fully stateless: check out each tag
and rebuild. Rejected on cost — O(N) macOS builds per merge to `main`, so the
tenth release adds roughly half an hour to every merge.

## Scope

**In:** the `pages-site` store, the `pages.yml` modification, `pages-release.yml`,
the four guards, `/v/index.html`, and the README line.

**Out:**

- Backfilling 2.x and 3.0.0.
- Publishing release candidates.
- A version switcher inside the report.
- Reducing render size (`-z`, dropping videos). Worth revisiting only if the
  size guard ever fires.
- Changing what `/` shows. It stays `main`.

## Risks

**The environment policy is not changed.** Then `pages-release.yml` fails at the
deploy step on the first release. The failure is loud rather than silent, but the
prerequisite above must land first.

**A tag render fails to build.** `publish-version` fails, so `deploy` — which
declares `needs: publish-version` — never runs and the live site is left
untouched. The release simply has no versioned page, and the workflow run is
red. That is the correct outcome, and it comes from job ordering rather than
from any guard.

`versions.json` is written **after** a successful render, never before, so a
failed render cannot leave the store declaring a version whose directory does
not exist.

**Double render on release.** A tag push renders the tag, then renders `main`
again during assembly — roughly three extra minutes, a few times a year. Caching
`main`'s render to avoid it would add state to save two minutes and is not worth
it.

**Site growth outlives the assumption.** At ~44 MB/year the 1 GB limit is two
decades away, but the size guard exists so the assumption is checked rather than
trusted.
