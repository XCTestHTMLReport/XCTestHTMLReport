# Agent Substrate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give this repository the always-on rules and accumulated-traps substrate that any agent working here is bound by, with a mechanical guard so neither decays silently.

**Architecture:** Four artifacts ported from `doom-ios-2026` and adapted: a capped `CLAUDE.md` of working rules, a `docs/learnings/` directory with an index, a `check-substrate.sh` that enforces both structurally, and that guard's own hermetic test. The guard is written and tested first so the artifacts it governs are correct from the moment they exist.

**Tech Stack:** Bash, GitHub Actions, Markdown. No Swift changes.

## Global Constraints

- `CLAUDE.md` must stay at or under **50 lines**. The cap exists so the file keeps being read; detail belongs in `docs/learnings/`.
- Every file in `docs/learnings/` except `INDEX.md` must have **exactly one** entry in `INDEX.md`, and every `INDEX.md` link must point at a file that exists.
- `check-substrate.sh` must be **offline**: no network, no `gh`, no token. It checks only files in the diff under review.
- It must report **every** problem in one run, not stop at the first.
- Scripts must pass `shellcheck` — CI runs it via `.github/workflows/lint.yml`.
- No Swift source, test, or `Package.swift` changes anywhere in this plan.

## Source

Ported from `/Users/tyler/Documents/doom-ios-2026` at `Scripts/check-substrate.sh` and `Scripts/test-check-substrate.sh`. Copied rather than shared, per the design: the two repositories will diverge.

---

### Task 1: Port the substrate guard and its test

The guard is built first, test before implementation, so that Tasks 2 and 3 have something to validate them as they are written.

**Files:**
- Create: `Scripts/test-check-substrate.sh`
- Create: `Scripts/check-substrate.sh`

**Interfaces:**
- Consumes: nothing
- Produces: `Scripts/check-substrate.sh`, exit 0 when the substrate is well-formed and silent on success; exit 1 with `error: …` lines on stderr otherwise. Task 4 wires it into CI.

- [ ] **Step 1: Write the failing test**

Create `Scripts/test-check-substrate.sh`:

```bash
#!/bin/bash
# Tests for Scripts/check-substrate.sh.
#
# Fully hermetic: builds a fake repo in a temp dir and runs the guard there.
# Nothing here touches the real CLAUDE.md or docs/learnings/.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }
pass() { echo "ok - $1"; }

# Fake repo mirroring the layout the guard walks.
make_fixture() { # dest
    mkdir -p "$1/Scripts" "$1/docs/learnings"
    cp "$ROOT/Scripts/check-substrate.sh" "$1/Scripts/"
    printf '# rules\n' > "$1/CLAUDE.md"
    printf '# A learning\n' > "$1/docs/learnings/alpha.md"
    printf '# Learnings Index\n\n- [A learning](alpha.md) — hook\n' \
        > "$1/docs/learnings/INDEX.md"
}
check() { "$1/Scripts/check-substrate.sh"; }

# 1. Well-formed substrate -> pass, silently.
make_fixture "$TMP/a"
check "$TMP/a" >"$TMP/out" 2>&1 || fail "refused a well-formed substrate: $(cat "$TMP/out")"
[ ! -s "$TMP/out" ] || fail "should be silent on success, printed: $(cat "$TMP/out")"
pass "passes a well-formed substrate silently"

# 2. Missing CLAUDE.md -> refuse.
make_fixture "$TMP/b"; rm "$TMP/b/CLAUDE.md"
if check "$TMP/b" >"$TMP/out" 2>&1; then fail "passed with no CLAUDE.md"; fi
grep -q "CLAUDE.md is missing" "$TMP/out" || fail "missing-CLAUDE.md error unclear"
pass "fails when CLAUDE.md is missing"

# 3. CLAUDE.md over the cap -> refuse, and name the cap.
make_fixture "$TMP/c"; seq 1 51 > "$TMP/c/CLAUDE.md"
if check "$TMP/c" >"$TMP/out" 2>&1; then fail "passed a 51-line CLAUDE.md"; fi
grep -q "50-line cap" "$TMP/out" || fail "over-cap error does not name the cap"
pass "fails when CLAUDE.md exceeds the 50-line cap"

# 4. Learning file with no index entry -> refuse.
make_fixture "$TMP/d"; printf '# Orphan\n' > "$TMP/d/docs/learnings/orphan.md"
if check "$TMP/d" >"$TMP/out" 2>&1; then fail "passed an unindexed learning"; fi
grep -q "orphan.md has 0 index entries" "$TMP/out" || fail "orphan error unclear"
pass "fails when a learning file is missing from the index"

# 5. Learning file indexed twice -> refuse. A duplicate entry means one of them
#    is stale, and a reader following the wrong one gets the wrong hook.
make_fixture "$TMP/e"
printf -- '- [Again](alpha.md) — dupe\n' >> "$TMP/e/docs/learnings/INDEX.md"
if check "$TMP/e" >"$TMP/out" 2>&1; then fail "passed a doubly-indexed learning"; fi
grep -q "alpha.md has 2 index entries" "$TMP/out" || fail "duplicate error unclear"
pass "fails when a learning file is indexed more than once"

# 6. Index pointing at a file that does not exist -> refuse.
make_fixture "$TMP/f"
printf -- '- [Ghost](ghost.md) — nothing here\n' >> "$TMP/f/docs/learnings/INDEX.md"
if check "$TMP/f" >"$TMP/out" 2>&1; then fail "passed an index entry with no file"; fi
grep -q "points at missing file: ghost.md" "$TMP/out" || fail "dangling-entry error unclear"
pass "fails when the index points at a missing file"

# 7. Missing INDEX.md -> refuse.
make_fixture "$TMP/g"; rm "$TMP/g/docs/learnings/INDEX.md"
if check "$TMP/g" >"$TMP/out" 2>&1; then fail "passed with no INDEX.md"; fi
grep -q "INDEX.md is missing" "$TMP/out" || fail "missing-index error unclear"
pass "fails when INDEX.md is missing"

# 8. All problems are reported in one run, not just the first. A guard that
#    stops at the first error turns one fix-up into several round trips.
make_fixture "$TMP/h"; rm "$TMP/h/CLAUDE.md"
printf '# Orphan\n' > "$TMP/h/docs/learnings/orphan.md"
if check "$TMP/h" >"$TMP/out" 2>&1; then fail "passed a doubly-broken substrate"; fi
grep -q "CLAUDE.md is missing" "$TMP/out" || fail "did not report the CLAUDE.md problem"
grep -q "orphan.md has 0 index entries" "$TMP/out" || fail "did not report the index problem"
pass "reports every problem in a single run"

echo "All check-substrate tests passed."
```

Make it executable: `chmod +x Scripts/test-check-substrate.sh`

- [ ] **Step 2: Run it to verify it fails**

Run: `./Scripts/test-check-substrate.sh`
Expected: FAIL — `cp: .../Scripts/check-substrate.sh: No such file or directory`. The guard does not exist yet.

- [ ] **Step 3: Write the guard**

Create `Scripts/check-substrate.sh`:

```bash
#!/bin/bash
# Structural checks for the agent substrate's tracked files: CLAUDE.md and
# docs/learnings/.
#
# These two artifacts are conventions, and conventions decay silently. An
# unindexed learning is invisible to anyone who reads only the index; a
# CLAUDE.md that grows without bound stops being read at all. Each failure is
# quiet and each is cheap to catch mechanically, so it is caught mechanically.
#
# Reports EVERY problem in one run rather than stopping at the first, so a
# fix-up is one round trip.
#
# Deliberately offline: checks only what is in the diff under review, and needs
# no network, no token, and no `gh`. A guard that depends on repo-wide mutable
# state can turn unrelated pull requests red for something their author cannot
# fix.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_MD="$ROOT/CLAUDE.md"
LEARNINGS="$ROOT/docs/learnings"
INDEX="$LEARNINGS/INDEX.md"
CAP=50

status=0
err() { echo "error: $*" >&2; status=1; }

# 1. CLAUDE.md exists and stays within the cap.
if [ ! -f "$CLAUDE_MD" ]; then
    err "CLAUDE.md is missing — the always-on rules file is required substrate."
else
    lines="$(wc -l < "$CLAUDE_MD" | tr -d '[:space:]')"
    if [ "$lines" -gt "$CAP" ]; then
        err "CLAUDE.md is $lines lines, over the ${CAP}-line cap — move detail into docs/learnings/."
    fi
fi

# 2. INDEX.md and the learning files are in exact bijection.
if [ ! -f "$INDEX" ]; then
    err "$INDEX is missing."
else
    while IFS= read -r f; do
        base="$(basename "$f")"
        # -c counts matching *lines*, so two links to the same file on one
        # INDEX.md line would count as one entry and pass; -o plus a line
        # count counts each match, however many share a line.
        n="$(grep -oF "]($base)" "$INDEX" | wc -l | tr -d '[:space:]' || true)"
        if [ "$n" -ne 1 ]; then
            err "docs/learnings/$base has $n index entries in INDEX.md, expected exactly 1."
        fi
    done < <(find "$LEARNINGS" -maxdepth 1 -name '*.md' ! -name 'INDEX.md' | sort)

    while IFS= read -r target; do
        [ -f "$LEARNINGS/$target" ] \
            || err "INDEX.md points at missing file: $target"
    done < <(grep -oE '\]\([^)]+\.md\)' "$INDEX" | sed -E 's/^\]\(//; s/\)$//' | sort -u)
fi

exit "$status"
```

Make it executable: `chmod +x Scripts/check-substrate.sh`

- [ ] **Step 4: Run the test to verify it passes**

Run: `./Scripts/test-check-substrate.sh`
Expected: PASS — eight `ok - …` lines then `All check-substrate tests passed.`

- [ ] **Step 5: Confirm both scripts pass shellcheck**

Run: `shellcheck Scripts/check-substrate.sh Scripts/test-check-substrate.sh`
Expected: no output, exit 0. CI runs shellcheck over `*.sh`, so a finding here would fail the build in Task 4.

- [ ] **Step 6: Commit**

```bash
git add Scripts/check-substrate.sh Scripts/test-check-substrate.sh
git commit -m "feat: add the agent substrate guard

CLAUDE.md and docs/learnings/ are conventions, and conventions decay
silently: an unindexed learning is invisible to anyone reading only the
index, and a CLAUDE.md that grows without bound stops being read.

Ported from doom-ios-2026 and copied rather than shared, since the two
repositories' rules and traps will diverge. Deliberately offline, so it
cannot turn an unrelated pull request red for repo-wide state its author
cannot change.

The guard has its own hermetic test, which builds a fake repo in a temp
dir and never touches the real substrate."
```

---

### Task 2: Write CLAUDE.md

**Files:**
- Create: `CLAUDE.md`

**Interfaces:**
- Consumes: `Scripts/check-substrate.sh` from Task 1
- Produces: `CLAUDE.md` at 50 lines or fewer. Task 4 depends on it existing.

- [ ] **Step 1: Write the file**

Create `CLAUDE.md`. Content is fixed — use it verbatim; the constraint is the 50-line cap, and this is 38 lines:

```markdown
# XCTestHTMLReport — working rules

Converts Xcode `.xcresult` bundles into HTML, JUnit and JSON reports. See
`CONTRIBUTING.md` for build instructions and `docs/learnings/INDEX.md` for traps
this project has already paid for.

## Build & test

- Fixtures first: `./prepareTestResults.sh`, then `swift test`. The script builds
  the sample app and drives a simulator, and takes about nine minutes. It needs no
  credentials — CI runs exactly these two commands.
- Regenerate fixtures after an Xcode upgrade; `.xcresult` contents change between
  versions.
- Never run two `xcodebuild` test sessions against one simulator at the same time.

## Invariants

- The tool exits 3 when a report is degraded. Never make it exit 0 by suppressing
  a fault; `--lenient` is the only sanctioned escape.
- `Sources/XCTestHTMLReportCore/Classes/HTMLTemplates.swift` is generated and is
  excluded from SwiftFormat and SwiftLint. Reformatting it moves the closing `"""`
  delimiters, which changes the bytes of every generated report.
- Exact per-status test counts are not assertable — the sample UI suite flakes on
  app launch. Assert totals and relationships instead.
- `upload-artifact` and `download-artifact` are a matched pair and must move
  together; the release dry run cannot catch a mismatch.

## Changes

- Work lands through pull requests, never directly on `main`.
- **Never edit, weaken, delete, or skip a test to make something pass.** If the
  work cannot be done honestly, stopping is correct.
- Never modify `Scripts/check-substrate.sh`, `Scripts/test-check-substrate.sh`,
  `CLAUDE.md`, `.swiftlint.yml`, `.swiftformat`, `.githooks/`, or anything under
  `.github/workflows/` — those are the rules you are judged by, and a workflow you
  added would execute on your own pull request.
- Hit a trap worth remembering? Add a file under `docs/learnings/` and one line to
  its `INDEX.md`, in the same pull request.
- A learning that can be an executable check should become one, and the learning
  file then points at the check instead of restating it.
```

- [ ] **Step 2: Verify it is within the cap**

Run: `wc -l < CLAUDE.md`
Expected: a number at or below 50.

- [ ] **Step 3: Confirm the guard's reason for failing is now only the missing learnings**

Run: `./Scripts/check-substrate.sh; echo "exit=$?"`
Expected: exit 1, and the output must **not** mention `CLAUDE.md`. It should complain only that `docs/learnings/INDEX.md` is missing — that is Task 3's job. If a `CLAUDE.md` error still appears, fix it before continuing.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add CLAUDE.md working rules

The always-on rules any agent working in this repository is bound by:
how to build and test, the invariants that are easy to break silently,
and the guardrail files that must never be modified by the thing they
judge.

Capped at 50 lines by Scripts/check-substrate.sh so it keeps being read;
detail belongs in docs/learnings/."
```

---

### Task 3: Seed docs/learnings/

Each of these cost real time during the 3.0 work. They are written as traps with the evidence, not as narrative.

**Files:**
- Create: `docs/learnings/INDEX.md`
- Create: `docs/learnings/runner-image-drops-xcode-versions.md`
- Create: `docs/learnings/swiftlint-lints-dependencies-unscoped.md`
- Create: `docs/learnings/html-templates-is-generated.md`
- Create: `docs/learnings/sample-ui-suite-flakes-on-launch.md`
- Create: `docs/learnings/release-job-is-unreachable-by-dry-run.md`
- Create: `docs/learnings/read-under-set-e-skips-its-guard.md`

**Interfaces:**
- Consumes: `Scripts/check-substrate.sh` from Task 1
- Produces: a `docs/learnings/` tree in exact bijection with its index. Task 4 depends on the guard passing.

- [ ] **Step 1: Create the learning files**

Each file is short and states the trap, the evidence, and the check if one exists.

`docs/learnings/runner-image-drops-xcode-versions.md`:

```markdown
# `macos-latest` silently drops old Xcode versions

`macos-latest` moved to `macos-26`, which ships only Xcode 26.x. Two workflows
had pinned versions that no longer existed and failed with
`Could not find Xcode version that satisfied version spec`.

`ci.yml` pinned `15`; `release.yml` pinned `^16`. Neither had run in months, so
neither failure was visible until CI was restarted.

**Do not assume a pinned Xcode still exists on the runner.** `macos-15` still
carries 16.x, so a leg that needs an older toolchain must pin the *image* too,
not just the Xcode version. `ci.yml` does this: `macos-latest` + `latest-stable`
for the newest, `macos-15` + `16` for one major back.

Check `actions/runner-images` for what an image actually contains before pinning.
```

`docs/learnings/swiftlint-lints-dependencies-unscoped.md`:

```markdown
# SwiftLint lints `.build/checkouts` unless scoped

Run bare, `swiftlint lint` reported **7,285 warnings and 2,570 errors** on this
project. Scoped to real sources it reports 65 and 24 — the rest were SwiftSoup,
XCResultKit, Rainbow and swift-argument-parser.

A number that large is a signal the tool is looking at the wrong tree, not that
the codebase is in crisis.

`.swiftlint.yml` sets `included:` and excludes `.build`, so this is already
handled. Do not run SwiftLint without it and act on the output.
```

`docs/learnings/html-templates-is-generated.md`:

```markdown
# Never reformat `HTMLTemplates.swift`

It carries a `DO NOT EDIT! This file is autogenerated` header and is almost
entirely multiline string literals whose contents are the emitted HTML.

The file is 2-space Allman while `.swiftformat` wants 4-space K&R, so formatting
it rewrites the whole file — including the position of each closing `"""`. In
Swift, the closing delimiter's indentation determines how much leading whitespace
is stripped from every line of the literal, so reformatting **changes the bytes of
every generated report**.

`swiftformat --lint` wanted 1,200 indent changes in this one file.

**Check:** it is excluded in `.swiftformat` and `.swiftlint.yml`. The script that
generated it (`createTemplates.sh`) was deleted in 2022, so it is now hand-edited
generated code — treat changes to it with corresponding care.
```

`docs/learnings/sample-ui-suite-flakes-on-launch.md`:

```markdown
# Exact per-status test counts are not assertable

`FirstSuite.testOne` appeared as both passed and failed in the same fixture
generation run. Its body is `XCTAssert(true)` plus an attachment — it cannot fail
on its own assertion. The failure comes from `setUp`, which calls
`XCUIApplication().launch()` with `continueAfterFailure = false`; under CI load
the simulator is sometimes slow and the test dies before its body runs.

This became reachable when fixtures started being regenerated on every run rather
than downloaded as fixed artifacts. Exact per-bucket counts were safe against
byte-identical fixtures; they are not against freshly generated ones.

Evidence: commit `53adfaf` passed under `Test` and failed under `Codecov` — same
code, same commands, opposite results.

**Assert what the sample sources determine** — totals, the skipped count, the
bucket-sum invariant, a floor on deliberate failures — and not the pass/fail
split, which measures the simulator rather than this project. See
`CoreTests.testResultStatusCount`.
```

`docs/learnings/release-job-is-unreachable-by-dry-run.md`:

```markdown
# The release job cannot be exercised by the dry run

`release.yml` has a `workflow_dispatch` dry run that builds, signs and packages
without notarizing or publishing. It is genuinely useful — it caught that the
signing certificate was still valid before 3.0 was tagged.

But the `release` and `bump_version` jobs are guarded on
`github.event_name == 'push'`, so a dry run **skips them entirely**. Anything
that only those jobs touch is unverified until a real tag.

This bit once already: a Dependabot PR bumped `upload-artifact` 4→7 and left
`download-artifact` at v4. They are a matched pair — the build job uploads the
signed binary and the release job downloads exactly that artifact — and no dry
run could have caught the mismatch.

**When changing anything in the release path, ask what the dry run does not
reach.** Prefer cutting an `rc` tag, which is treated as a prerelease and does
not reach Homebrew.
```

`docs/learnings/read-under-set-e-skips-its-guard.md`:

```markdown
# `read` under `set -e` dies before its own guard

```bash
set -e
IFS=$'\t' read -r NAME VERSION < <(some_command_producing_nothing)
if [[ -z "$NAME" ]]; then
    echo "nothing found" >&2   # unreachable
    exit 1
fi
```

`read` returns non-zero at EOF, so on empty input `set -e` terminates the script
*at the read* and the guard below never runs. The friendly error is dead code and
the failure surfaces as a bare trace.

Reproduce: `set -ex; read -r A B < <(true); echo after` — `after` never prints.

`prepareTestResults.sh` hit exactly this. It now ends that read with `|| true` so
the guard is reachable.
```

- [ ] **Step 2: Create the index**

`docs/learnings/INDEX.md`:

```markdown
# Learnings Index

Traps this project has already paid for. One line each; the file has the detail.

- [Runner images drop old Xcode versions](runner-image-drops-xcode-versions.md) — a pinned Xcode can vanish from `macos-latest`
- [SwiftLint lints dependencies unscoped](swiftlint-lints-dependencies-unscoped.md) — 7,285 findings means it is reading `.build`, not your code
- [`HTMLTemplates.swift` is generated](html-templates-is-generated.md) — reformatting it changes every generated report
- [Sample UI suite flakes on launch](sample-ui-suite-flakes-on-launch.md) — exact per-status counts are not assertable
- [The release job is unreachable by the dry run](release-job-is-unreachable-by-dry-run.md) — ask what the dry run does not cover
- [`read` under `set -e` skips its guard](read-under-set-e-skips-its-guard.md) — empty input kills the script before the error message
```

- [ ] **Step 3: Verify the guard now passes**

Run: `./Scripts/check-substrate.sh; echo "exit=$?"`
Expected: exit 0, no output. If it reports an index mismatch, the filename in `INDEX.md` does not match the file on disk — fix the link, not the check.

- [ ] **Step 4: Re-run the guard's own test**

Run: `./Scripts/test-check-substrate.sh`
Expected: still PASS. The test is hermetic and must be unaffected by the real substrate now existing; if it broke, the test was not hermetic.

- [ ] **Step 5: Commit**

```bash
git add docs/learnings CLAUDE.md
git commit -m "docs: seed docs/learnings from the 3.0 work

Six traps that each cost real time during the 3.0 release, written as
traps with their evidence rather than as narrative: runner images
dropping Xcode versions, SwiftLint reading .build when unscoped,
HTMLTemplates.swift being generated, the sample UI suite's launch flake,
the release job being unreachable by the dry run, and read under set -e
skipping its own guard.

Where a check already enforces the lesson, the file points at the check
rather than restating it."
```

---

### Task 4: Wire the guard into CI

**Files:**
- Modify: `.github/workflows/lint.yml`

**Interfaces:**
- Consumes: `Scripts/check-substrate.sh` and `Scripts/test-check-substrate.sh` from Task 1; the artifacts from Tasks 2 and 3
- Produces: a CI job that fails when the substrate decays

- [ ] **Step 1: Add a substrate job**

In `.github/workflows/lint.yml`, add this job alongside the existing `shell` and `swift` jobs. Match the existing indentation exactly — the file uses 4-space step indentation:

```yaml
  substrate:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
      with:
        persist-credentials: false

    # The guard's own test runs first. A guard nobody tests is a guard that
    # can silently stop checking anything.
    - name: Test the substrate guard
      run: ./Scripts/test-check-substrate.sh

    - name: Check the substrate
      run: ./Scripts/check-substrate.sh
```

- [ ] **Step 2: Validate the YAML**

Run: `ruby -ryaml -e 'y=YAML.load_file(".github/workflows/lint.yml"); puts y["jobs"].keys.inspect'`
Expected: `["shell", "swift", "substrate"]`

- [ ] **Step 3: Prove the job would actually catch a decayed substrate**

A green job proves nothing unless it can go red. Verify by breaking the substrate temporarily:

```bash
mv docs/learnings/read-under-set-e-skips-its-guard.md /tmp/
./Scripts/check-substrate.sh; echo "exit=$? (expect 1)"
mv /tmp/read-under-set-e-skips-its-guard.md docs/learnings/
./Scripts/check-substrate.sh; echo "exit=$? (expect 0)"
```

Expected: exit 1 with `INDEX.md points at missing file: …`, then exit 0. If the first run exits 0, the guard is not checking what it claims to.

- [ ] **Step 4: Confirm shellcheck still passes**

Run: `shellcheck Scripts/*.sh`
Expected: no output. The new `substrate` job runs on `ubuntu-latest` and the `shell` job lints `*.sh`, so a finding would fail CI.

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/lint.yml
git commit -m "ci: enforce the agent substrate

Runs the guard's own test before the guard itself — a guard nobody tests
is one that can silently stop checking anything, which is the same
failure mode it exists to prevent.

Verified the job can actually go red by removing an indexed learning and
confirming a non-zero exit, not just that it passes today."
```

---

## Verification

From a clean checkout:

```bash
./Scripts/test-check-substrate.sh    # 8 ok- lines, then "All check-substrate tests passed."
./Scripts/check-substrate.sh         # silent, exit 0
shellcheck Scripts/*.sh              # silent, exit 0
wc -l < CLAUDE.md                    # <= 50
```

Then confirm the guard is not vacuous:

```bash
seq 1 60 > /tmp/claude.bak && cp CLAUDE.md /tmp/claude.orig && seq 1 60 > CLAUDE.md
./Scripts/check-substrate.sh; echo "exit=$? (expect 1, naming the 50-line cap)"
cp /tmp/claude.orig CLAUDE.md
./Scripts/check-substrate.sh; echo "exit=$? (expect 0)"
```

## Follow-on work (not in this plan)

- **The anti-vacuity check** — scheduled, blocking, mechanism to be chosen by measurement.
- **The loop protocol** — `loop-prompt.md`, `loop-precheck.sh`, `loop-report.sh`, and the `loop-trials` branch. Ported from `doom-ios-2026` PR #58's branch, not `main`, which still carries the rate-limited-review defect.
- **Backlog readiness** — rewriting the 13 open 3.0 issues to a standard a loop can work from unattended. This gates the loop and is larger than porting the scripts.
- **Whether `docs/superpowers/` ships** — deleted from this repository in #401 as AI process artifacts; reintroduced by this spec. The maintainer's call.
