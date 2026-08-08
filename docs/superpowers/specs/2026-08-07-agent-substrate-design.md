# Agent Substrate for XCTestHTMLReport — Design

**Date:** 2026-08-07
**Author:** Tyler Vick (with Claude)
**Status:** Approved for planning

## Context

3.0.0 shipped today, and with it the verification oracle that makes agent work
checkable at all: `swift test` runs on any clone without credentials, the tool exits
non-zero on a degraded report, and three linters gate every pull request.

The original brainstorm (`2026-08-06-repo-revival-design.md`) deferred the autonomous
code lane on the grounds that an agentic loop without a trustworthy oracle produces
plausible-looking garbage at scale. That objection is now answered. This design covers
what comes next.

It is deliberately **not** a from-scratch design. `doom-ios-2026` already runs an agent
loop with a mature substrate, and this repository should adopt it rather than invent a
parallel one.

## The failure class this exists to address

A day of work on this repository produced six cases where a signal did not mean what it
appeared to mean:

| Signal read | What was actually authoritative |
| --- | --- |
| SonarCloud check-run conclusion (red) | Sonar's `issues/search` API — `CLOSED / FIXED` |
| Review comments on a pull request | comment `created_at` versus the fix commit's time |
| "CodeRabbit: pass" | whether a review body exists — it was rate-limited |
| `git diff main..branch` | `git diff $(git merge-base ...)..branch` |
| "8 known pre-existing failures" | re-running them; two were caused by this branch |
| Reading a YAML diff | parsing the YAML and walking the jobs |

Every one was a **derived or cached representation** rather than the state itself.

The same class appears independently in `doom-ios-2026`'s own trial record for run
`2026-08-08T012411Z-issue-13`:

> the CodeRabbit check itself reports `Review rate limited` — and reports it as `pass`,
> so the check-level view looks entirely healthy while zero review bodies exist …
> `coderabbit_findings_first: none` can mean "nothing was ever measured", not "nothing
> was found".

Two repositories, hours apart, same failure. That is the argument for designing against
it rather than treating either instance as bad luck.

## Goals

1. Port the proven substrate from `doom-ios-2026` rather than reinventing it.
2. Seed it with what this repository has already learned, in executable form wherever
   possible.
3. Add the one mechanism the existing substrate lacks: something that detects a test
   which passes for the wrong reason.

## Non-goals

- A general-purpose framework spanning all six of Tyler's repositories. Build it
  concretely here; generalize only when a second repository actually needs it.
- Running the loop autonomously before the backlog is written to a standard it can work
  from (see Sequencing).

## Design

### 1. Port the substrate, with copies rather than references

Adopt, adapted to this repository:

| Artifact | Purpose |
| --- | --- |
| `CLAUDE.md` | working rules binding any agent in this repo |
| `docs/learnings/` + `INDEX.md` | traps this project has already paid for |
| `Scripts/check-substrate.sh` | structural checks on the two above |
| `Scripts/test-check-substrate.sh` | the test of that guardrail |
| `Scripts/loop-prompt.md` | the unattended run protocol |
| `Scripts/loop-precheck.sh` | decides whether a run should start at all |
| `Scripts/loop-report.sh` | reads the trial records |
| `docs/loop-trials/` | the experiment's data, on its own branch |

**Copied, not shared.** These will diverge: the build is SwiftPM rather than Xcode
schemes, there is no engine pin or TestFlight path, and this repository's hazards are
its own. Extracting a common core from two examples would be premature, and a shared
`loop-prompt.md` would have to carry both repositories' specifics to serve either.

**Port from PR #58's branch, not `main`.** `tylervick/loop-independent-ci-review-poll`
is four commits ahead and unmerged, and it contains precisely the fix for the
rate-limited-review case above — polling CI and review independently so a stalled review
cannot turn a real CI conclusion into a timeout. Porting from `main` would import a known
defect. This creates a dependency: if #58 changes materially before merging, the port
must be re-synced.

### 2. Seed from what this repository already knows

`docs/learnings/` starts populated rather than empty. Each of these cost real time today
and each is a trap a future agent would otherwise re-pay:

- `macos-latest` became macos-26 and stopped shipping Xcode 16, silently breaking `ci.yml`
  and `release.yml`
- SwiftLint run unscoped lints `.build/checkouts`, reporting 7,285 findings instead of 65
- Reformatting `HTMLTemplates.swift` moves the closing `"""` delimiters and changes the
  bytes of every generated report
- `xcresulttool --legacy` is why Swift Testing display names and tags never surface
- The sample UI suite flakes on `XCUIApplication().launch()`, so exact per-status counts
  are not assertable
- `upload-artifact` and `download-artifact` are a matched pair the release dry run cannot
  validate, because the release job only runs on a tag push
- A `read` under `set -e` returns non-zero on empty input and dies before its own guard
- Reports are not reproducible: five `UUID()` call sites mint fresh DOM handles per run

Per `CLAUDE.md`'s own rule — *a learning that can be an executable check should become
one* — several already are: the `--strict` exit codes, the lint configuration, and
`release.yml`'s "Verify the built binary reports the tagged version" step. The learning
file points at the check rather than restating it.

### 3. The new piece: an anti-vacuity check

The existing substrate's absolutes include *"never edit, weaken, delete, or skip a test
to make something pass"*. That is a rule with no mechanism behind it, and today produced
two tests that passed for the wrong reason:

- an idempotency test asserting `0 == 0`, which would have passed with the dedup logic
  deleted outright
- a status-count assertion that measured simulator reliability rather than the report
  generator

Both were caught by a human asking *would this still pass if the thing it tests were
removed?* Nothing mechanical asks that.

**Posture: scheduled and blocking, not per-pull-request.** Nightly, across the suite,
filing an issue when a test cannot be shown to catch anything. Rationale: the `test` job
already takes about ten minutes, of which 85% is fixture generation (#412), and adding a
second suite run to every pull request would make that worse for a class of defect that
is not urgent within a single review cycle. Scheduled catches it after merge, which is
later but not too late.

**Mechanism is left to the implementation plan.** Options include `muter` (a Swift
mutation-testing tool), reverting the source hunk a test covers and asserting the test
then fails, and an agent-driven pass reasoning over the diff. Each has real drawbacks —
`muter`'s runtime against a ten-minute suite, hunk attribution being unreliable, an
agent-driven check being exactly the kind of judgment this is meant to replace. Choosing
between them needs measurement, not argument.

### 4. The invariant that makes it safe

Carried over verbatim in spirit: **an agent must never be able to weaken the check that
judges it.** In `doom-ios-2026` this is enforced by naming the guardrail files as
unmodifiable, including the tests of the guardrails themselves, and by forbidding any
change under `.github/workflows/` — since a workflow an agent added would execute on its
own pull request.

This repository needs the same list, with its own contents: `Scripts/loop-*`,
`Scripts/check-substrate.sh` and its test, `CLAUDE.md`, `.swiftlint.yml`, `.swiftformat`,
`.githooks/`, and everything under `.github/workflows/`.

## Sequencing

1. **Substrate first** — `CLAUDE.md`, `docs/learnings/`, `check-substrate.sh` and its
   test. Useful immediately for supervised agent work, with no loop involved.
2. **Anti-vacuity check** — prototype, measure, choose a mechanism, then wire it to a
   schedule.
3. **Loop protocol** — port `loop-prompt.md`, `loop-precheck.sh`, `loop-report.sh`, and
   the `loop-trials` branch.
4. **Backlog readiness** — see below. The loop does not run until this is done.

## The precondition nobody should skip

`doom-ios-2026`'s loop selects from issues labelled `agent:eligible`, and
`check-issue-format.sh` enforces that such issues are specified well enough to work
unattended. This repository's 3.0 milestone currently holds 13 open issues written for a
human reader — they describe problems, not verifiable tasks.

**Rewriting those to the `agent:eligible` bar is the real prerequisite**, and it is
larger than porting the scripts. An agent loop pointed at under-specified issues produces
confident, wrong work — the failure the original spec deferred Track C to avoid.

## Risks

| Risk | Mitigation |
| --- | --- |
| PR #58 changes before merging, so the port drifts from its source | Re-sync before the loop lands; the substrate steps do not depend on it |
| Copies diverge and a fix in one repository is not applied to the other | Accepted deliberately; revisit only if a third repository appears |
| The anti-vacuity check is slow or noisy enough to be ignored | Measure before choosing a posture; scheduled rather than blocking per PR |
| The loop runs against under-specified issues | Backlog rewrite gates the loop, not the other way round |
| Learnings decay into prose nobody reads | `check-substrate.sh` enforces indexing; prefer executable checks over files |

## Open question for the maintainer

`docs/superpowers/` was deliberately removed from this repository in #401, on the
grounds that AI-workflow process artifacts should not ship in a public repo. This spec
reintroduces that directory.

`doom-ios-2026` keeps its specs and plans in-tree. The substrate this describes —
`CLAUDE.md`, `docs/learnings/`, `Scripts/` — genuinely belongs in the repository, since
it binds anyone working there. Whether the *design documents* do is a separate call, and
is the maintainer's to make before this merges.
