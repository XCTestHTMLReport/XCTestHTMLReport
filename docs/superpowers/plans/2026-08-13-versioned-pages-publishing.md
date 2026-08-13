# Versioned Pages Publishing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish a rendered demo report for every stable release under
`/v/<tag>/`, alongside `main`'s render at the root, without the frequent path
ever needing write access.

**Architecture:** A `pages-site` branch stores only immutable release renders.
`pages.yml` checks it out read-only on every merge to `main`, renders `main` into
the root, and deploys the whole tree. `pages-release.yml` is the only thing that
writes: on a stable tag it renders that tag into the store, then calls
`pages.yml` via `workflow_call` to assemble and deploy.

**Tech Stack:** GitHub Actions, `actions/upload-pages-artifact` +
`actions/deploy-pages`, Python 3 (assembly and guards), Swift 5.5 / SwiftPM for
the render.

**Spec:** `docs/superpowers/specs/2026-08-13-versioned-pages-publishing-design.md`

## Global Constraints

- **The prerequisite is already satisfied.** The `github-pages` environment now
  carries `branch: main` and `tag: *.*.*` deployment policies. Deployment
  policy patterns support `*` but **not** `+` or character classes, so `*.*.*`
  is the tightest expressible form and would also admit `3.0.0rc1`. The real
  stable-only gate is `pages-release.yml`'s trigger glob, which does support
  `+`. Do not treat the loose policy as the filter.
- `zizmor --min-severity low` audits `.github/workflows/`. Pin every action by
  full commit SHA with a trailing `# vX.Y.Z` comment, set
  `persist-credentials: false` on every checkout that does not push, and scope
  `permissions` per job.
- `actionlint` must be clean on every workflow file.
- The `shell` CI job runs `shellcheck` over every `*.sh` in the repo and is a
  **required** check. This plan adds no shell scripts, deliberately: macOS
  runners ship bash 3.2 (no `mapfile`, no associative arrays), and the guards
  are easier to get right in Python. Follow `scripts/select_simulator.py`'s
  precedent.
- Required status checks on `main` are `shell`, `swift`, `test (auto)`,
  `test (modern)`, `dump`, `visual`. All must be green.
- Do not change what `/` serves. It stays `main`'s render.
- `pages.yml` renders the **real** `TestResults.xcresult` fixture (not the
  synthetic one), so it needs the fixture cache and `prepareTestResults.sh`.
  That is unchanged by this work — do not remove those steps.
- The size ceiling is **800 MB** for the assembled site, against a 1 GB Pages
  limit.
- Never bypass the pre-commit hook (`core.hooksPath` → `.githooks/`). If git
  signing fails with a keychain error, retry; never fall back to unsigned.

## File Structure

**Created:**

| path | responsibility |
|---|---|
| `scripts/assemble_site.py` | assemble `_site`, generate the version listing, run all four guards |
| `.github/workflows/pages-release.yml` | render a stable tag into the store, then call `pages.yml` |

**Modified:**

| path | change |
|---|---|
| `.github/workflows/pages.yml` | add `workflow_call`; check out the store; call the assembler |
| `README.md` | link the version listing |

**Created outside the working tree:** the `pages-site` branch (Task 2).

---

### Task 1: The assembler and its guards

This script is where every failure mode this design worries about is caught.
`deploy-pages` replaces the entire site, so a run that assembles an incomplete
tree deletes published versions *and reports success*. Everything below exists
to make that loud.

**Files:**
- Create: `scripts/assemble_site.py`

**Interfaces:**
- Produces: `python3 scripts/assemble_site.py <site-dir>` — exits 0 on a valid
  assembled site, non-zero with a `::error::` line otherwise. Writes
  `<site-dir>/v/index.html`. Removes `<site-dir>/.git`.

- [ ] **Step 1: Write the script**

```python
#!/usr/bin/env python3
"""Assemble the published Pages site and refuse to publish a damaged one.

The site is main's render at the root plus one immutable directory per released
version. `actions/deploy-pages` replaces the whole site on every deployment, so
a run that assembles an incomplete tree would silently delete published versions
and still finish green. Every check here exists to turn that into a failure.

Usage: assemble_site.py <site-dir>
"""

import html
import json
import os
import shutil
import sys

# 1 GB is the documented Pages site limit. Failing at 800 MB turns the ceiling
# into a CI failure with headroom instead of a rejected deployment.
MAX_BYTES = 800 * 1024 * 1024


def fail(message):
    print(f"::error::{message}", file=sys.stderr)
    sys.exit(1)


def directory_size(path):
    total = 0
    for root, _, files in os.walk(path):
        for name in files:
            total += os.path.getsize(os.path.join(root, name))
    return total


def render_listing(versions):
    """A minimal static index. Deliberately depends on nothing in the report
    templates, so template changes never churn it."""
    items = "\n".join(
        f'      <li><a href="./{html.escape(v)}/">{html.escape(v)}</a></li>'
        for v in versions
    )
    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>XCTestHTMLReport — published versions</title>
  <style>
    body {{ font-family: system-ui, -apple-system, sans-serif; margin: 3rem auto;
           max-width: 40rem; padding: 0 1rem; line-height: 1.6; }}
    li {{ margin: 0.25rem 0; }}
  </style>
</head>
<body>
  <h1>Published versions</h1>
  <p>Each link is the demo report as rendered by that release.
     <a href="../">The site root</a> is always the current <code>main</code>.</p>
  <ul>
{items}
  </ul>
</body>
</html>
"""


def main():
    if len(sys.argv) != 2:
        fail("usage: assemble_site.py <site-dir>")
    site = sys.argv[1]

    # actions/checkout leaves a full repository behind, and
    # upload-pages-artifact packages whatever it is handed — without this the
    # store's git history is published as browsable files.
    shutil.rmtree(os.path.join(site, ".git"), ignore_errors=True)

    manifest = os.path.join(site, "versions.json")
    if not os.path.isfile(manifest):
        fail(f"missing {manifest} — the pages-site store was not checked out")

    if not os.path.isfile(os.path.join(site, "index.html")):
        fail(f"missing {site}/index.html — main's render did not land")

    with open(manifest, encoding="utf-8") as handle:
        try:
            versions = json.load(handle)
        except json.JSONDecodeError as error:
            fail(f"{manifest} is not valid JSON: {error}")

    if not isinstance(versions, list) or any(not isinstance(v, str) for v in versions):
        fail(f"{manifest} must be a flat array of version strings")

    # Truncation guard. Every declared version must exist on disk. A version
    # that vanished between the store and the artifact would otherwise deploy
    # as a green run that quietly dropped it.
    missing = [v for v in versions if not os.path.isfile(
        os.path.join(site, "v", v, "index.html"))]
    if missing:
        fail(
            f"versions.json declares {len(missing)} version(s) with no render: "
            f"{', '.join(missing)}"
        )

    # The reverse direction matters too: a directory nobody declared means the
    # manifest and the tree disagree, and the listing would omit a live page.
    version_dir = os.path.join(site, "v")
    on_disk = sorted(
        name for name in os.listdir(version_dir)
        if os.path.isdir(os.path.join(version_dir, name))
    ) if os.path.isdir(version_dir) else []
    undeclared = [name for name in on_disk if name not in versions]
    if undeclared:
        fail(
            f"{len(undeclared)} version director(ies) not in versions.json: "
            f"{', '.join(undeclared)}"
        )

    os.makedirs(version_dir, exist_ok=True)
    with open(os.path.join(version_dir, "index.html"), "w", encoding="utf-8") as handle:
        handle.write(render_listing(versions))

    size = directory_size(site)
    if size > MAX_BYTES:
        fail(
            f"assembled site is {size / 1024 / 1024:.0f} MB, over the "
            f"{MAX_BYTES / 1024 / 1024:.0f} MB ceiling"
        )

    print(f"assembled {site}: {len(versions)} version(s), {size / 1024 / 1024:.1f} MB")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Verify the happy path**

```bash
cd /tmp && rm -rf sitetest && mkdir -p sitetest/v/3.1.0
echo '<!doctype html>main' > sitetest/index.html
echo '<!doctype html>v310' > sitetest/v/3.1.0/index.html
echo '["3.1.0"]' > sitetest/versions.json
python3 "$OLDPWD/scripts/assemble_site.py" sitetest; echo "exit=$?"
cat sitetest/v/index.html | head -20
```

Expected: exit 0, prints `assembled sitetest: 1 version(s), 0.0 MB`, and
`v/index.html` contains a link to `./3.1.0/`.

- [ ] **Step 3: Verify the truncation guard fires**

```bash
cd /tmp && rm -rf sitetest2 && mkdir -p sitetest2/v
echo '<!doctype html>main' > sitetest2/index.html
echo '["3.1.0","3.0.0"]' > sitetest2/versions.json
python3 "$OLDPWD/scripts/assemble_site.py" sitetest2; echo "exit=$?"
```

Expected: exit 1, `::error::versions.json declares 2 version(s) with no render: 3.1.0, 3.0.0`.

**This is the guard the whole design rests on.** If it exits 0, stop and report —
the design's central safety property is absent.

- [ ] **Step 4: Verify the undeclared-directory guard fires**

```bash
cd /tmp && rm -rf sitetest3 && mkdir -p sitetest3/v/9.9.9
echo '<!doctype html>main' > sitetest3/index.html
echo '<!doctype html>v999' > sitetest3/v/9.9.9/index.html
echo '[]' > sitetest3/versions.json
python3 "$OLDPWD/scripts/assemble_site.py" sitetest3; echo "exit=$?"
```

Expected: exit 1, `::error::1 version director(ies) not in versions.json: 9.9.9`.

- [ ] **Step 5: Verify the missing-store and missing-render guards fire**

```bash
cd /tmp && rm -rf sitetest4 && mkdir -p sitetest4
python3 "$OLDPWD/scripts/assemble_site.py" sitetest4; echo "exit=$? (expect 1: missing versions.json)"
echo '[]' > sitetest4/versions.json
python3 "$OLDPWD/scripts/assemble_site.py" sitetest4; echo "exit=$? (expect 1: missing index.html)"
```

Expected: exit 1 both times, with the two distinct messages.

- [ ] **Step 6: Verify `.git` removal**

```bash
cd /tmp && rm -rf sitetest5 && mkdir -p sitetest5/v sitetest5/.git
echo secret > sitetest5/.git/config
echo '<!doctype html>main' > sitetest5/index.html
echo '[]' > sitetest5/versions.json
python3 "$OLDPWD/scripts/assemble_site.py" sitetest5
ls -a sitetest5 | grep -c '^\.git$' || echo "0 — .git removed, correct"
```

Expected: `.git` is gone.

- [ ] **Step 7: Commit**

```bash
cd /Users/tyler/Documents/XCTestHTMLReport
chmod +x scripts/assemble_site.py
git add scripts/assemble_site.py
git commit -m "Site assembler that refuses to publish a truncated version store"
```

---

### Task 2: Bootstrap the `pages-site` store

**Files:** none in the working tree — this task creates a branch.

**Interfaces:**
- Produces: branch `pages-site` containing `versions.json` (`[]`) and `v/.gitkeep`.

- [ ] **Step 1: Create the orphan branch**

Do this in a scratch clone so the working tree is never left on the store
branch:

```bash
cd /tmp && rm -rf storeinit
git clone --no-checkout "$(git -C /Users/tyler/Documents/XCTestHTMLReport remote get-url origin)" storeinit
cd storeinit
git checkout --orphan pages-site
git rm -rf --cached . 2>/dev/null || true
rm -rf ./* 2>/dev/null || true
mkdir -p v
echo '[]' > versions.json
touch v/.gitkeep
git add versions.json v/.gitkeep
git commit -m "Bootstrap the versioned Pages store"
git push -u origin pages-site
```

`v/.gitkeep` exists because git cannot track an empty directory, and
`assemble_site.py` lists `v/` before the first release adds anything to it.

- [ ] **Step 2: Verify the branch exists and holds only the store**

```bash
git -C /Users/tyler/Documents/XCTestHTMLReport fetch origin
git -C /Users/tyler/Documents/XCTestHTMLReport ls-tree -r --name-only origin/pages-site
```

Expected: exactly `v/.gitkeep` and `versions.json`. If any source file appears,
the orphan branch was created wrong — delete it and redo, rather than
committing a fix on top.

- [ ] **Step 3: Confirm the main working tree is untouched**

```bash
cd /Users/tyler/Documents/XCTestHTMLReport
git status --porcelain
git rev-parse --abbrev-ref HEAD
```

Expected: clean, and still on the feature branch — not `pages-site`.

---

### Task 3: Assemble from the store in `pages.yml`

**Files:**
- Modify: `.github/workflows/pages.yml`

**Interfaces:**
- Consumes: `scripts/assemble_site.py`, branch `pages-site`.
- Produces: `pages.yml` callable via `workflow_call`.

- [ ] **Step 1: Add the `workflow_call` trigger**

Replace the `on:` block:

```yaml
on:
  push:
    branches: [ main ]
  workflow_dispatch:
  # pages-release.yml calls this after writing a version into the store, so
  # assembly and deployment exist in exactly one place.
  workflow_call:
```

- [ ] **Step 2: Check out the store before rendering**

Insert immediately after the existing `actions/checkout` step in the `build`
job:

```yaml
    # The version store, checked out read-only. Its renders are immutable and
    # main's is not stored here at all — that asymmetry is what keeps this
    # workflow, which runs on every merge, free of write access.
    - name: Check out the version store
      uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      with:
        ref: pages-site
        path: _site
        persist-credentials: false
```

- [ ] **Step 3: Assemble after rendering**

The existing `Render demo report` step does `mkdir -p _site` — remove that line,
because the checkout above already created `_site` and `mkdir -p` on an existing
directory is now misleading rather than harmful. The step becomes:

```yaml
    - name: Render demo report
      run: |
        .build/release/xchtmlreport -i \
          -o _site \
          Tests/XCTestHTMLReportTests/Resources/TestResults.xcresult
```

Then insert a new step directly before `Upload Pages artifact`:

```yaml
    # Removes the store's .git, generates the version listing, and refuses to
    # continue if the assembled tree does not match versions.json. deploy-pages
    # replaces the entire site, so publishing a truncated tree would delete
    # released versions in a run that still reported success.
    - name: Assemble and verify the site
      run: python3 scripts/assemble_site.py _site
```

- [ ] **Step 4: Lint**

```bash
zizmor --min-severity low .github/workflows/pages.yml
actionlint .github/workflows/pages.yml
```

Expected: both clean.

- [ ] **Step 5: Commit and push**

```bash
git add .github/workflows/pages.yml
git commit -m "Assemble the demo site from the versioned store"
git push
```

**`pages.yml` triggers only on push to `main` and `workflow_dispatch`, so no PR
run will exercise it.** That is the awkward part of this task: the change cannot
be proven until it reaches `main`. Do not claim it works before then.

Once merged, trigger it explicitly rather than waiting for the next merge:

```bash
gh workflow run "Demo Site" --ref main
sleep 20 && gh run list --workflow=pages.yml --limit 1
gh run watch "$(gh run list --workflow=pages.yml --limit 1 --json databaseId --jq '.[0].databaseId')"
```

Expected: both jobs green, and the `Assemble and verify the site` step printing
`assembled _site: 0 version(s), ~11 MB`. Zero versions is correct before the
first release.

- [ ] **Step 6: Confirm the deployed site still serves main and now serves the listing**

```bash
curl -s -o /dev/null -w "root: HTTP %{http_code} %{size_download} bytes\n" -L https://xctesthtmlreport.github.io/XCTestHTMLReport/
curl -s -o /dev/null -w "listing: HTTP %{http_code}\n" -L https://xctesthtmlreport.github.io/XCTestHTMLReport/v/
```

Expected: root 200 with roughly 11 MB, listing 200. The listing will show no
versions until the first release — that is correct, not a failure.

---

### Task 4: `pages-release.yml`

**Files:**
- Create: `.github/workflows/pages-release.yml`

**Interfaces:**
- Consumes: `scripts/assemble_site.py`, branch `pages-site`, `pages.yml`'s
  `workflow_call`.

- [ ] **Step 1: Write the workflow**

```yaml
name: Demo Site (release)

# Publishes a permanent render for each stable release under /v/<tag>/, so the
# site can answer "what did the report look like in 3.0" and not only "what
# does it look like right now".
on:
  push:
    tags:
    # Stable only. release.yml needs a second, separate pattern for
    # `[0-9]+.[0-9]+.[0-9]+rc[0-9]+`, which is what tells us this one does not
    # match release candidates.
    - '[0-9]+.[0-9]+.[0-9]+'

permissions:
  contents: read

# Deliberately NOT the `pages` group. This workflow calls pages.yml, and a
# called reusable workflow evaluates its own `concurrency` — so if this one
# already held `pages`, the call would wait for a group its own caller is
# holding and the run would deadlock. This group protects the store push from
# concurrent releases; pages.yml keeps serialising the deployment itself.
concurrency:
  group: pages-store
  cancel-in-progress: false

jobs:
  publish-version:
    runs-on: macos-latest
    # The only job in either workflow that writes. It pushes one immutable
    # directory into the pages-site store; everything else reads.
    permissions:
      contents: write
    steps:
    - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      with:
        persist-credentials: false

    - name: Setup Xcode version
      uses: maxim-lobanov/setup-xcode@ed7a3b1fda3918c0306d1b724322adc0b8cc0a90 # v1.7.0
      with:
        xcode-version: latest-stable

    # No cache restore: this tag's sample app differs from main's, so the
    # shared fixture key would miss anyway. A few minutes, a few times a year.
    - name: Generate test fixtures
      run: ./prepareTestResults.sh

    - name: Verify fixture
      run: |
        plist="Tests/XCTestHTMLReportTests/Resources/TestResults.xcresult/Info.plist"
        if [ ! -f "$plist" ]; then
          echo "::error::missing or incomplete fixture: TestResults.xcresult"
          exit 1
        fi

    - name: Build
      run: swift build -c release --product xchtmlreport

    - name: Render this release
      run: |
        mkdir -p render
        .build/release/xchtmlreport -i \
          -o render \
          Tests/XCTestHTMLReportTests/Resources/TestResults.xcresult

    # Checked out with credentials, because this one pushes.
    - name: Check out the version store
      uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      with:
        ref: pages-site
        path: store

    # versions.json is written only after the render succeeded, so a failed
    # build can never leave the store declaring a version whose directory does
    # not exist. Re-running a tag overwrites its directory rather than
    # appending, so a re-run cannot corrupt the store.
    - name: Write the version into the store
      env:
        TAG: ${{ github.ref_name }}
      run: |
        mkdir -p "store/v/$TAG"
        cp render/index.html "store/v/$TAG/index.html"
        python3 - "$TAG" <<'PY'
        import json, sys
        tag = sys.argv[1]
        with open("store/versions.json", encoding="utf-8") as handle:
            versions = json.load(handle)
        if tag not in versions:
            versions.insert(0, tag)
        with open("store/versions.json", "w", encoding="utf-8") as handle:
            json.dump(versions, handle, indent=2)
            handle.write("\n")
        PY
        cd store
        git config user.name "github-actions[bot]"
        git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
        git add "v/$TAG/index.html" versions.json
        git commit -m "Publish demo report for $TAG"
        git push

  # Reuses pages.yml wholesale rather than duplicating assembly and deploy.
  deploy:
    needs: publish-version
    uses: ./.github/workflows/pages.yml
    permissions:
      contents: read
      pages: write
      id-token: write
```

- [ ] **Step 2: Lint**

```bash
zizmor --min-severity low .github/workflows/pages-release.yml
actionlint .github/workflows/pages-release.yml
```

Expected: both clean. zizmor will notice the store checkout keeps its
credentials; that is deliberate because the step pushes. If zizmor flags it as
an error rather than a note, add a scoped suppression with a comment saying the
job pushes — do not remove the credentials, which would break the push.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/pages-release.yml
git commit -m "Publish a permanent demo render for every stable release"
```

- [ ] **Step 4: Confirm the deployment policy admits tag refs**

```bash
gh api repos/:owner/:repo/environments/github-pages/deployment-branch-policies \
  --jq '.branch_policies[] | "\(.type): \(.name)"'
```

Expected: `branch: main` and `tag: *.*.*`. Without the tag entry the deploy job
is rejected by the environment protection rule. Do not attempt to add it
yourself — report it as missing.

---

### Task 5: Point people at it

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add the listing link**

In `README.md`, the line currently reading:

```markdown
**[▶ Open a live report](https://xctesthtmlreport.github.io/XCTestHTMLReport/)** — rendered from this repository's own sample test run, republished on every merge to `main`.
```

becomes:

```markdown
**[▶ Open a live report](https://xctesthtmlreport.github.io/XCTestHTMLReport/)** — rendered from this repository's own sample test run, republished on every merge to `main`. Past releases are at **[/v/](https://xctesthtmlreport.github.io/XCTestHTMLReport/v/)**.
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "Link the published version listing from the README"
```

- [ ] **Step 3: Push and confirm the branch is green**

```bash
git push
gh pr checks --watch
```

Expected: `shell`, `swift`, `test (auto)`, `test (modern)`, `dump`, `visual` all
green.
