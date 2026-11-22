# XCTestHTMLReport — working rules

Converts Xcode `.xcresult` bundles into HTML, JUnit and JSON reports.
`CONTRIBUTING.md` covers building, testing and how outside contributions are
handled; `docs/learnings/INDEX.md` lists traps this project has already paid for.

## Build & test

- Tools are pinned in `mise.toml`; `mise trust && mise install` also installs
  the pre-commit hook defined in `hk.pkl`. `mise tasks` lists the scripts.
- Fixtures first: `./prepareTestResults.sh`, then `./scripts/verify_fixtures.sh`,
  then `swift test`. Regenerate fixtures whenever the Xcode changes.
- Never run two `xcodebuild` test sessions against one simulator at once. Pick
  an Xcode with `DEVELOPER_DIR` per command, never `xcode-select -s`.
- Script tests are stdlib `unittest` files, `scripts/test_*.py`, which the
  `shell` lint job discovers. A new guard is Python in `scripts/` with one.

## Invariants

- A degraded report exits 3. Never reach exit 0 by suppressing a fault;
  `--lenient` is the only sanctioned escape.
- `HTMLTemplates.swift` is hand-maintained and excluded from SwiftFormat and
  SwiftLint: reformatting it changes the bytes of every report.
- On generated fixtures, assert totals and relationships, never the exact
  pass/fail split.
- The release dry run never reaches the `release` job; a change there is
  unverified until a tag.

## How work flows

- GitHub issues are the backlog. Changes land through pull requests on a
  ruleset-protected `main`: required checks pass, squash merge only.
- The owner merges changes to the tool's source; an agent does not.
- An agent never runs a release step: tags, GitHub releases, the Homebrew bump,
  the Pages release.
- A red check is not always your diff: compare with `main`, re-run once.

## Changes

- Commit subjects are plain imperative sentences, as in `git log`.
- Never weaken, skip or delete a test to get a green run. When the work changes
  intended behaviour, update the tests that pin the old behaviour and list each
  one in the pull request description.
- Loosening a lint config, `hk.pkl`, a workflow or a guard is its own decision
  in its own pull request, never something done in passing.
- Hit a trap worth remembering? Add a file under `docs/learnings/` and one line
  to its `INDEX.md` in the same pull request. `scripts/check_agent_rules.py`
  holds this file to 50 lines and the index to the directory.
